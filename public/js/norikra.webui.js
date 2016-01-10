$(function(){

  $('.show-query-expression').each(function(i,e){
    $(this).bind('click', function(e){
      var button = $(this);
      if (! button.data('loaded')) {
        $.get(button.data('load'), function(data){
          button.attr('data-loaded', 'true');
          button.popover({
            placement: 'left',
            html: true,
            title: 'name:' + data.name + ', group:' + data.group,
            content: '<pre class="query-expression" style="border: none; width: 100%;">' + data.expression + '</pre>'
          }).popover('toggle');
          $('pre.query-expression').closest('div').css('padding', '0');
        });
        e.preventDefault();
      }
    });
  });

  $('.show-query-events-sample').each(function(i,e){
    $(this).bind('click', function(e){
      var button = $(this);
      if (! button.data('loaded')) {
        $.get(button.data('load'), function(data){
          var events_texts = data.map(function(d){ return JSON.stringify(d); }).join("\n");
          button.attr('data-loaded', 'true');
          button.popover({
            placement: 'left',
            html: true,
            title: 'Events sample',
            content: '<pre class="query-events-sample" style="border: none; width: 100%;">' + events_texts + '</pre>'
          }).popover('toggle');
          $('pre.query-events-sample').closest('div').css('padding', '0');
        });
        e.preventDefault();
      }
    });
  });

  $('.show-target-fields').each(function(i,e){
    $(this).bind('click', function(e){
      var button = $(this);
      if (! button.data('loaded')) {
        $.get(button.data('load'), function(data){
          var field_rows_html = data.fields.sort(function(a,b){
            if (a.name > b.name) return 1;
            if (a.name < b.name) return -1;
            return 0;
          }).map(function(t){
            return '<tr style="border:none;"><td>' + t.name
              + '</td><td>' + t.type + '</td><td>' + (t.optional ? '(optional)' : '') + '</td></tr>';
          }).join('');
          var table_html = '<table class="target-fields" style="border: 0; width: 100%;">'
                + '<tr><th>field</th><th>type</th><th></th></tr>'
                + field_rows_html
                + '</table>';
          button.attr('data-loaded', 'true');
          button.popover({
            placement: 'top',
            html: true,
            content: table_html
          }).popover('toggle');
          $('table.target-fields').closest('div').css('padding', '0');
        });
        e.preventDefault();
      }
    });
  });

  $('#query_add_editor_toggle').click(function(e){ $('#query_add_editor').toggle(); });
    $(document).ready(function(e) {
        if (document.location.hash === "#editQuery0"){
            $('#editQuery0').modal('show');
        }
    });

    //    $('.show-this-modal').load(function(e){ $(e.target).modal('show'); });
//    $('.show-this-modal').load(function(e){ alert("hello"); });
//    $('#editQueryButton0').mouseover(function(e){ $('#editQuery0').modal('show'); });

  $('#show_server_logs').click(function(e){
    var url = $(e.target).data('url');
    var logtable = $('#logtable');
    logtable.remove('tr.logline');
    $.get(url, function(data){
      data.forEach(function(log){
        logtable.append('<tr class="logline ' + log[1] + '"><td>' + log[0] + '</td><td>' + log[1] + '</td><td>' + log[2] + '</td>');
      });
    });
    $('#logsection').show();
  });

    $('#query_search_input').keyup(function(){
        if(!$(this).val()){
            $('#table_queries tr').show();
        }
        else {
            $('#table_queries tr').filter(':has(td)').hide();
            $('#table_queries tr:contains(' + this.value + ')').show();
        }
    });

    $('#target_search_input').keyup(function(){
        if(!$(this).val()){
            $('#table_targets tr').show();
        }
        else {
            $('#table_targets tr').filter(':has(td)').hide();
            $('#table_targets tr:contains(' + this.value + ')').show();
        }
    });

});
