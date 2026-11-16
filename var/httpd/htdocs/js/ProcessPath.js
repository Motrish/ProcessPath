(function () {
    'use strict';
    // Core inserts "Main" widgets after article items. Place ProcessPath directly
    // under the ticket action toolbar without modifying AgentTicketZoom.tt.
    function positionWidget() {
        var widget = document.getElementById('ProcessPathWidget');
        var actionRow = document.querySelector('.TicketZoom .ContentColumn .ActionRow');
        if (!widget || !actionRow) { return; }
        var actionWidget = actionRow.closest('.WidgetSimple');
        if (!actionWidget || !actionWidget.parentNode) { return; }
        actionWidget.parentNode.insertBefore(widget, actionWidget.nextSibling);
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', positionWidget);
    }
    else {
        positionWidget();
    }
}());
