import Em from 'ember';

export default Em.Component.extend({
  classNames: 'line-area-chart',
  height: 340,
  graph: null,

  draw: function() {
    var graph;
    var data;
    var xAxes;
    var yAxes;
    var detail;

    data = this.get('data').map(function(d) {
      return {
        x: moment(d[0]).unix(),
        y: d[1]
      };
    });

    graph = new Rickshaw.Graph({
      element: this.get('element'),
      width:   this.get('width'),
      height:  this.get('height'),
      renderer: 'area',
      xScale: d3.time.scale(),
      stroke: true,
      interpolation: 'linear',

      padding: {
        top: 0.25,
        left: 0,
        right: 0,
        bottom: 0.01
      },

      series: [{
        name: 'Requests',
        data: data.sortBy('x')
      }]
    });

    detail = new Rickshaw.Graph.HoverDetail({
      graph: graph,

      xFormatter: function(x) {
        return moment(x, 'X').format('ddd, MMM Do');
      },

      yFormatter: function(y) {
        return y;
      }
    });

    xAxes = new Rickshaw.Graph.Axis.Time({
      graph: graph
    });

    yAxes = new Rickshaw.Graph.Axis.Y({
      graph: graph,
      tickFormat: Rickshaw.Fixtures.Number.formatKMBT
    });

    graph.render();
    this.set('graph', graph);
  }.on('didInsertElement'),

  willInsertElement: function() {
    this.updateWidth();
    var barChartCommponent = this;
    $(window).on('resize.' + this.get('elementId'), function() {
      Em.run.debounce(barChartCommponent, 'updateWidth', 100);
    });
  },

  widthDidChange: function() {
    var graph = this.get('graph');
    if (Em.isEmpty(graph) || this.get('isDestroyed')) {return;}
    graph.configure({width: this.get('width')});
    graph.render();
  }.observes('width'),

  updateWidth: function() {
    this.set('width', this.$().parent().width());
  },

  willDestroyElement: function() {
    $(window).off('resize.' + this.get('elementId'));
  }
});
