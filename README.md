# jekyll-elasticsearch

jekyll-elasticsearch is a Jekyll plugin. It create elasticsearch index of jekyll posts on jekyll build.  
This plugin will add title, url, content, date and id(generated from url) of each post to elasticsearch.  
It also rewrite existed post data on each build, and find deleted post from elasticsearch and remove it.

tested on Elasticsearch ver.1.00 and gems jekyll(1.4.3), elasticsearch (1.0.0).

## Usage

### Jekyll settings

Add `_esplugin` directory to your jekyll directory.
You should not put this plugin into _plugin dir unless updating elasticsearch on every build and every edit while launching jekyll server.
Install rubygem `elasticserach` and `oj`.
Update your `_config.yml` to define your elasticsearch settings like so:

    elasticsearch:
        host: "localhost:9200" (required)
        index: "blog"          (required)
        type: "post"           (required)
        analyzer: "kuromoji"

* host: elasticserach host.
* index: elasticsearch index.
* type: elasticsearch type.
* analyzer: if you want to search Japanese, set "kuromoji". If not, you need not to add this config.

You can update elasticsearch records by building jekyll using plugin option.

    jekyll build -p _esplugin

### add your cleint javascript

You can use [elasticsearch/elasticsearch-js](https://github.com/elasticsearch/elasticsearch-js) to search posts on jekyll site.
If you use jquery, see sample-jekyll-elasticsearch.jquery.js.
You need to update host, index, type on it.

## License

jekyll-elasticsearch is distributed under the same license as Jekyll.

Copyright (c) 2014 Junichiro Takagi


