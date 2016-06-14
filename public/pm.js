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
pm.logTable.prototype.add = function(row) {
    if (row.action != this.type)
        throw 'Wrong table for entry';
    var rowElement = $(
        '<tr>'+
            '<td><div>'+pm.utils.escapeHTML(row.timestamp)+'</div></td>'+
            '<td><div>'+pm.utils.escapeHTML(row.package)+'</div></td>'+
            '<td><div>'+pm.utils.escapeHTML(row.version)+'</div></td>'+
            '<td><div>'+pm.utils.escapeHTML(row.arch)+'</div></td>'+
        '</tr>'
    );
    rowElement.data('row', row);
    this.rows[row.package] = rowElement;
    this.tableElement.prepend(rowElement);
    rowElement.find('div').slideDown();
};
pm.logTable.prototype.del = function(name) {
    if (typeof(name) !== 'string')
        throw 'Please provide package name as the first argument';
    var rowElement = this.rows[name];
    if (rowElement === undefined)
        return;

    delete this.rows[name];
    var divElements = rowElement.find('div');
    var i = divElements.length;
    divElements.slideUp(function() {
        i--;
        if (i == 0) rowElement.remove();
    });
};
pm.logTable.prototype.trim = function(limit) {
    if (typeof(limit) !== 'number')
        throw 'Please provide trim limit as the first argument';
    var length = this.tableElement.find('tr').length;
    var i = length - limit;
    while (i > 0) {
        var lastRow = this.tableElement.find(
            'tr:eq('+(length - i)+')'
        );
        this.del(lastRow.data('row').package);
        i--;
    }
}

/***********************
 *  adjustment logics  *
 ***********************/
pm.lockAdjastment = false;
pm.mostRecentEntry = undefined;
pm.adjustLog = function() {
    if (pm.lockAdjastment) return;
    pm.lockAdjastment = true;
    var url = '/whats_up'
    if (pm.mostRecentEntry !== undefined)
        url += '?after='+encodeURIComponent(
            pm.mostRecentEntry.timestamp
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
        pm.tables.install.del(entry.package);
        pm.tables.remove.del(entry.package);
        pm.tables[entry.action].add(entry);
    }
    var tableLimit = pm.entriesLimit / 2;
    pm.tables.install.trim(tableLimit);
    pm.tables.remove.trim(tableLimit);
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
