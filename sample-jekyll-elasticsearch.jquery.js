// This is a sample client javascript for jekyll-elastic search.
// you need to load jquery and elasticsearch.jquery.js before this js.
//  <script src="https://code.jquery.com/jquery-1.10.2.min.js"></script>
//  <script src="/js/elasticsearch.jquery.min.js"></script>

$(document).ready(function() {

  var client = new $.es.Client({
    host: 'localhost:92000',
    log:  'trace',
    apiVersion: '1.0'
  });

  // parse query
  function getQueryParams(qs) {
    qs = qs.split("+").join(" ");
    var params = {}, tokens,
        re = /[?&]?([^=]+)=([^&]*)/g;

    while (tokens = re.exec(qs)) {
      params[decodeURIComponent(tokens[1])]
        = decodeURIComponent(tokens[2]);
    }
    return params;
  }

  function showResult(posts) {
    if (posts.length == 0) {
      $("div#main").append("No Result.");
    } else {
      var str = "<ul>";
      for (var i=0; i<posts.length; i++) {
        var post = posts[i];
        str += "<li><a href=\"" + post.url + "\">" + post.title + "</a>";
        str += "<small> on ";
        post.date.match(/^(\d+)-(\d+)-(\d+)/);
        str += RegExp.$1 + "/" +  RegExp.$2 + "/" + RegExp.$3;
        str += "</small></li>\n";
      }
      str += "</ul>";
      $("div#main").append(str);
    }
  }

  function showError() {
    $("div#main").empty();
    $("div#main").append("Search system error.");
  }
  
  var query = getQueryParams(document.location.search);
  $("div#query").text("search \"" + query.q +"\"");

  // check elasticsearch server
  // client.ping({
  //   requestTimeout: 1000,
  //   // undocumented params are appended to the query string
  //   hello: "elasticsearch!"
  // }, function (error) {
  //   if (error) {
  //     console.error('elasticsearch cluster is down!');
  //   } else {
  //     console.log('All is well');
  //   }
  // });

  // search post from elasticsearch
  client.search({
    index: "blog",
    type:  "post",
		body: {
      query: {
        match: {
          _all: query.q
        }
      },
      fields: ["title", "url", "post_date"],
      sort: [{
        post_date: {
          order: "desc"
        }
      }]
    }
  }).then(function (resp) {
    var posts = [];
    var hits = resp.hits.hits;

    for (var i=0; i<hits.length; i++) {
      var title = hits[i].fields.title[0];
      var url = hits[i].fields.url[0];
      var date = hits[i].fields.post_date[0];
      var post = {
        title: title,
        url:   url,
        date:  date
      };
      posts.push(post);
    }
    // show result
    showResult(posts);
  }, function (err) {
    console.trace(err.message);
    showError();
  });
})
