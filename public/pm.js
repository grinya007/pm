"use strict";
var pm = {};

/***************************
 *  client initialization  *
 ***************************/
pm.initialized = false;
pm.init = function() {

    // these objects will be tied to real tables on page
    pm.tables = {};
    pm.tables.install = new pm.logTable('install');
    pm.tables.remove  = new pm.logTable('remove');
    
    // initial adjustment
    // will do "whats_up" call without "after" argument
    // also will set pm.initialized to true on success
    pm.adjustLog();

    // setting poll interval
    // pm.refreshInterval and few other settings
    // are defined in index template
    setInterval(pm.adjustLog, pm.refreshInterval);

};

// on document ready
$(pm.init);


/************************
 *   websocket client   *
 ************************/
pm.ws = undefined;

// whether client is initially connecting
// or trying to reconnect after server
// has gone beyond the horizon, client gets here
pm.startWs = function(onConnected) {
    pm.ws = new WebSocket(pm.wsUrl);
    pm.ws.onopen = onConnected;
    pm.ws.onmessage = pm.handleResponse;
    pm.ws.onerror = function() {
        // will show amazing dyno taken from Google Chrome
        $('div.no-connection').show();
        pm.lockAdjastment = false;
    };
};

// if check passes onConnected() is just fired right here
pm.checkWs = function(onConnected) {
    if (pm.ws && pm.ws.readyState == 1) onConnected();
    else pm.startWs(onConnected);
};


/***********************
 *  adjustment logics  *
 ***********************/

// pm.adjustLog() calls need to be synchronous
// since table rows animation takes time a bit
// and may possibly become broken in parallel
pm.lockAdjastment = false;

// will just keep the most recent log entry
// entries come in timestamp ascending order
pm.mostRecentEntry = undefined;

pm.adjustLog = function() {
    if (pm.lockAdjastment) return;
    pm.lockAdjastment = true;
    var req = {};
    if (pm.mostRecentEntry !== undefined)
        // setting "after" arg to request only new entries
        req.after = pm.mostRecentEntry.hash;
    pm.checkWs(function() {
        // if we get here, we may hide dyno
        // the connection is ok
        $('div.no-connection').hide();
        pm.ws.send(JSON.stringify(req));
    });
};

// the main driver function
pm.handleResponse = function(res) {
    // checking status
    res = JSON.parse(res.data);
    if (!res.ok) throw res.error;
    if (res.tail.length == 0) {
        pm.lockAdjastment = false;
        return;
    }
    // got new entries
    for (var i in res.tail) {
        
        // unfortunately, no data validation here
        // which is definitely TODO
        // even despite our data sorce is trusted
        var entry = res.tail[i];
        pm.mostRecentEntry = entry;

        // _name attr will keep a unique key for particular package
        // almost same as hash attribute does, but not taking
        // timestamp and action into account
        // generally, if the package is installed say by mistake
        // and then removed in a minute - same rows on top of both
        // "installed" and "removed" tables will most likely be
        // confusing, that's why unifying packages we'll get only
        // one row in "removed" table in such situation
        entry._name =
            entry.package+'_'+entry.version+'_'+entry.arch;

        // trying to delete entries from both tables
        // it's ok if they are not there
        pm.tables.install.del(entry._name, {'animate': pm.initialized});
        pm.tables.remove.del(entry._name, {'animate': pm.initialized});

        // finally add it to a proper table
        pm.tables[entry.action].add(entry, {'animate': pm.initialized});
    }

    // pm.entriesLimit is defined in index template
    // devided by half since unlike server-side
    // here we keep two tables in mind
    var tableLimit = pm.entriesLimit / 2;
    pm.tables.install.trim(tableLimit, {'animate': pm.initialized});
    pm.tables.remove.trim(tableLimit, {'animate': pm.initialized});

    if (!pm.initialized) {
        console.log(res);
        // initial animation happens here (don't ask)
        pm.tables.install.tableElement.children().show();
        pm.tables.install.tableElement.find('div').slideDown();
        pm.tables.remove.tableElement.children().show();
        pm.tables.remove.tableElement.find('div').slideDown();
        
        // initialization magic is complete
        pm.initialized = true;
    }

    // releasing adjustment function
    pm.lockAdjastment = false;
};


/*****************
 *  table class  *
 *****************/

// a bit on JavaScript prototype-based OOP
pm.logTable = function(type) {
    // constuction
    if (type != 'install' && type != 'remove')
        throw 'Unknown log type';
    this.type = type;
    this.tableElement = $('table.'+type+' > tbody');
    this.rows = {};
};
pm.logTable.prototype.add = function(entry, opts) {
    // adding entry
    opts = opts || {'animate': true};
    if (entry.action != this.type)
        throw 'Wrong table for entry';
    var rowElement = $(
        '<tr>'+
            '<td><div>'+pm.utils.escapeHTML(entry.timestamp)+'</div></td>'+
            '<td><div>'+pm.utils.escapeHTML(entry.package)+'</div></td>'+
            '<td><div>'+pm.utils.escapeHTML(entry.version)+'</div></td>'+
            '<td><div>'+pm.utils.escapeHTML(entry.arch)+'</div></td>'+
        '</tr>'
    );
    rowElement.data('entry', entry);
    this.rows[entry._name] = rowElement;
    this.tableElement.prepend(rowElement);
    if (opts.animate) {
        rowElement.show();
        rowElement.find('div').slideDown();
    }
};
pm.logTable.prototype.del = function(name, opts) {
    // deleting entry by it's _name
    opts = opts || {'animate': true};
    if (typeof(name) !== 'string')
        throw 'Please provide package name as the first argument';
    var rowElement = this.rows[name];
    if (rowElement === undefined)
        return;

    delete this.rows[name];
    if (opts.animate) {
        var divElements = rowElement.find('div');
        var i = divElements.length;
        divElements.slideUp(function() {
            i--;
            if (i == 0) rowElement.remove();
        });
    }
    else {
        rowElement.remove();
    }
};
pm.logTable.prototype.trim = function(limit, opts) {
    // trimming table
    opts = opts || {'animate': true};
    if (typeof(limit) !== 'number')
        throw 'Please provide trim limit as the first argument';
    var length = this.tableElement.children('tr').length;
    var i = length - limit;
    while (i > 1) {
        var lastRow = this.tableElement.children(
            'tr:eq('+(length - i)+')'
        );
        if (lastRow.length == 0) break;
        this.del(lastRow.data('entry')._name, opts);
        i--;
    }
}


/*****************
 *     utils     *
 *****************/
pm.utils = {};
pm.utils.escapeHTML = function(string) {
    if (string === undefined)
        return '';
    if (typeof(string) !== 'string')
        throw 'Bad string argument';
    var entityMap = {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': '&quot;',
        "'": '&#39;',
        "/": '&#x2F;'
    };

    // just to insure against <script>alert('boom')</script> like packages =)
    return String(string).replace(/[&<>"'\/]/g, function (s) {
        return entityMap[s];
    });
};

