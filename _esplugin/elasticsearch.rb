# encoding: utf-8

# Jekyll plugin for elasticsearch.
# Add post to elasticsearch
# See readme file for documenation
#
# Author: Junichiro Takagi
# Source:

require 'elasticsearch'
require 'oj'
require 'digest/md5'

module Jekyll

  class JekyllElasticsearch
    def initialize(host, index, type)
      if host == nil ||index == nil || type == nil
        raise "argument error"
      end
      @es = Elasticsearch::Client.new hosts: "#{host}", log: true
      @index = index
      @type = type
    end

    def set_analyzer (analyzer)
      @analyzer = analyzer
    end

    def type_exists
      @es.indices.exists_type index: "#{@index}", type: "#{@type}"
    end

    def index_exists
      @es.indices.exists index: "#{@index}"
    end

    def create_index
      settings = nil
      if @analyzer
        # use custom analyzer
        settings = get_setting
      end

      post_id = { "type" => "long", "include_in_all" => false, "store" => true }
      post_date = { "type" => "date", "include_in_all" => false, "store" => true }
      es_update_date = { "type" => "date", "include_in_all" => false, "store" => true }
      url = { "type" => "string", "include_in_all" => false, "store" => true }
      if @analyzer
        title = { "type" => "string", "store" => true, "index" => "analyzed", "analyzer" => "#{@analyzer}" }
        content = { "type" => "string", "store" => true, "index" => "analyzed", "analyzer" => "#{@analyzer}" }
      else
        title = { "type" => "string", "store" => true, "index" => "analyzed" }
        content = { "type" => "string", "store" => true, "index" => "analyzed" }
      end

      _id = { "path" => "post_id" }
      _timestamp = { "enabled" => true, "path" => "post_date" }
      _source = { "enabled" => false }
      if @analyzer
        _all = { "enabled" => true, "analyzer" => "#{@analyzer}" }
      else
        _all = { "enabled" => true }
      end
      properties = { "post_id" => post_id, "post_date" => post_date, "es_update_date" => es_update_date,
                     "url" => url, "title" => title, "content" => content }

      post = { "_id" => _id, "_timestamp" => _timestamp, "_source" => _source,
               "_all" => _all, "properties" => properties }
      mappings = { "#{@type}" => post }

      body = settings ? { "settings" => settings, "mappings" => mappings } : { "mappings" => mappings }

      @es.indices.create index: "#{@index}", body: Oj.dump(body)
    end

    def delete_index
      @es.indices.delete index: "#{@index}"
    end

    def create_post(body)
      @es.index index: "#{@index}", type: "#{@type}", body: body
    end

    def update_post(postid, body)
      @es.update index: "#{@index}", type: "#{@type}", id: postid, body: body
    end

    def post_exists(post_id)
      @es.exists index:"#{@index}", type: "#{@type}", id: "#{post_id}"
    end

    def delete_old_posts(date)
      res = @es.delete_by_query index:"#{@index}", type: "#{@type}", body: {
        query: {
          range: {
            es_update_date: {
              to: "#{date}"
            }
          }
        }
      }
    end

    def refresh
      @es.indices.refresh index: "#{@index}"
    end

    # return settings for analyzer.
    def get_setting()
      if @analyzer  == 'kuromoji'
        # use kuromoji. need to install kuromoji-plugin for elasticsearch
        pos_filter = { "type" => "kuromoji_part_of_speech", "stoptags" => ["助詞-格助詞-一般", "助詞-終助詞"]}
        greek_lowercase_filter = {"type" => "lowercase", "langrage" => "greek"}
        filter = { "pos_filter" => pos_filter, "greek_lowercase_filter" => greek_lowercase_filter }

        kuromoji = { "type" => "kuromoji_tokenizer", "mode" => "search" }
        tokenizer = { "kuromoji" => kuromoji }

        kuromoji_filter = ["kuromoji_baseform", "pos_filter", "greek_lowercase_filter", "cjk_width"]
        kuromoji_analyzer = { "type" => "custom", "tokenizer" => "kuromoji", "filter" => kuromoji_filter }
        analyzer = { "#{@analyzer}" => kuromoji_analyzer }

        analysis = { "filter" => filter, "tokenizer" => tokenizer, "analyzer" => analyzer }
        settings = { "analysis" => analysis }
      else
        raise "[elasticsearch plugin]: undefined analyzer #{analyzer}"
      end
    end
  end


  class ElasticSearchGenerater < Generator
    priority :low
    safe true

    def generate(site)
      #config
      es_config = site.config['elasticsearch']
      unless es_config
        raise "[elasticsearch plugin]: no config for elasticsearch in _config.yml."
      end

      host = es_config['host']
      index = es_config['index']
      type = es_config['type']
      analyzer = es_config['analyzer']

      unless host && index && type
        raise "[elasticsearch plugin]: 'host', 'index' and 'type' config is required."
      end

      # initalize
      es = JekyllElasticsearch.new host, index, type
      if analyzer != nil
        es.set_analyzer analyzer
      end

      # if db is not exists, create one.
      unless es.type_exists
        es.create_index
        # wait index created
        sleep 2
      end

      now = Time.now
      site.posts.reverse.each_with_index do |post, i|
        post_id = Digest::MD5.hexdigest(post.url).hex % (2**32)
        data = {
          # create uniq id from url.
          "post_id" => post_id,
          "post_date" => post.date.strftime("%FT%T%z"),
          # set elastic update time to find removed post after.
          "es_update_date" => now.strftime("%FT%T%z"),
          "title" => post.title,
          "url" => "#{site.config['url']}#{post.url}",
          "content" => post.content
        }

        es.refresh
        es.create_post Oj.dump(data)
      end
      # delete removed post from elasticsearch
      es.refresh
      es.delete_old_posts (now - 1).strftime("%FT%T%z")

    end

  end

end
