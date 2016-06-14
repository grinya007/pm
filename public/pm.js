var pm = {};

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
    return String(string).replace(/[&<>"'\/]/g, function (s) {
        return entityMap[s];
    });
};

/*****************
 *  table class  *
 *****************/
pm.logTable = function(type) {
    if (type != 'install' && type != 'remove')
        throw 'Unknown log type';
    this.type = type;
    this.tableElement = $('table.'+type+' > tbody');
    this.rows = {};
};
pm.logTable.prototype.add = function(entry, opts) {
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
    opts = opts || {'animate': true};
    if (typeof(limit) !== 'number')
        throw 'Please provide trim limit as the first argument';
    var length = this.tableElement.find('tr').length;
    var i = length - limit;
    while (i > 0) {
        var lastRow = this.tableElement.find(
            'tr:eq('+(length - i)+')'
        );
        this.del(lastRow.data('entry')._name, opts);
        i--;
    }
}

/***********************
 *  adjustment logics  *
 ***********************/
pm.initialized = false;
pm.lockAdjastment = false;
pm.mostRecentEntry = undefined;
pm.adjustLog = function() {
    if (pm.lockAdjastment) return;
    pm.lockAdjastment = true;
    var url = '/whats_up'
    if (pm.mostRecentEntry !== undefined)
        url += '?after='+encodeURIComponent(
            pm.mostRecentEntry.hash
        );
        $.getJSON(url, pm.handleResponse).fail(function () {
            pm.lockAdjastment = false;
        });
};
pm.handleResponse = function(newEntries) {
    if (newEntries.length == 0) {
        pm.lockAdjastment = false;
        return;
    }
    for (var i in newEntries) {
        var entry = newEntries[i];
        pm.mostRecentEntry = entry;
        entry._name =
            entry.package+'_'+entry.version+'_'+entry.arch;
        pm.tables.install.del(entry._name, {'animate': pm.initialized});
        pm.tables.remove.del(entry._name, {'animate': pm.initialized});
        pm.tables[entry.action].add(entry, {'animate': pm.initialized});
    }
    var tableLimit = pm.entriesLimit / 2;
    pm.tables.install.trim(tableLimit, {'animate': pm.initialized});
    pm.tables.remove.trim(tableLimit, {'animate': pm.initialized});

    if (!pm.initialized) {
        pm.tables.install.tableElement.children().show();
        pm.tables.install.tableElement.find('div').slideDown();
        pm.tables.remove.tableElement.children().show();
        pm.tables.remove.tableElement.find('div').slideDown();
        pm.initialized = true;
    }
    pm.lockAdjastment = false;
};

pm.init = function() {
    pm.tables = {};
    pm.tables.install = new pm.logTable('install');
    pm.tables.remove  = new pm.logTable('remove');
    pm.adjustLog();
    setInterval(pm.adjustLog, 1000);
};
$(pm.init);
