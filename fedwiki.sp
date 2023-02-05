dashboard "fedwiki" {

  container {

    input "since" {
      width = 2
      title = "updated since"
      sql = <<EOQ
        with days(interval, day) as (
        values
          ( '1 week', to_char(now() - interval '1 week', 'YYYY-MM-DD') ),
          ( '2 weeks', to_char(now() - interval '2 week', 'YYYY-MM-DD') ),
          ( '1 month', to_char(now() - interval '1 month', 'YYYY-MM-DD') ),
          ( '3 months', to_char(now() - interval '3 month', 'YYYY-MM-DD') ),
          ( '6 months', to_char(now() - interval '6 month', 'YYYY-MM-DD') ),
          ( '1 year', to_char(now() - interval '1 year', 'YYYY-MM-DD') ),
          ( '2 years', to_char(now() - interval '2 year', 'YYYY-MM-DD') )
        )
        select
          interval as label,
          day as value
        from
          days
        order by
          day desc
      EOQ    
    }  

    
    graph {

      node {
        category = category.document
        args = [ self.input.since.value ]
        sql = <<EOQ
          select
            slug as id,
            slug as title
          from
            fedwiki_data()
          where
            updated > $1
        EOQ
      }

      edge {
        category = category.link
        sql = <<EOQ
          select
            slug as from_id,
            link as to_id
          from
            fedwiki_data()
        EOQ
      }    

    }

  }

  container {
  
    input "limit" {
      width = 2
      title = "limit"
      sql = <<EOQ
        with limits(label) as (
          values
            ( '5' ),
            ( '10' ),
            ( '20' ),
            ( '50' ),
            ( '100' )
        )
        select
          label,
          label::int as value
        from
          limits
      EOQ
    }

    container {

      table {
        title = "ward.dojo.fed.wiki link counts"
        width = 4
        args = [ self.input.limit.value ]
        sql = <<EOQ
          select
            *
          from
            fedwiki_data()
          limit $1
        EOQ
      }

      table {
        width = 4
        title = "ward.dojo.fed.wiki links by recently-updated pages"
        args = [ self.input.limit.value ]
        sql = <<EOQ
          select
            *
          from
            fedwiki_data()
          order by
            updated desc nulls last
          limit $1
        EOQ
      }

      chart {
        type = "donut"
        width = 4
        title = "ward.dojo.fed.wiki links by frequency"
        args = [ self.input.limit.value ]
        sql = <<EOQ
          select
            slug,
            count(*)
          from
            fedwiki_data()
          group by
            slug
          order by
            count desc
          limit $1
        EOQ
      }

    }

  }

  with "fedwiki_data" {
    sql = <<EOQ
      create or replace function fedwiki_data() returns table (
        slug text,
        updated text,
        link text
      ) as $$
      with data as (
        select
          jsonb_array_elements(response_body::jsonb) as json,
          jsonb_object_keys(
            jsonb_array_elements(response_body :: jsonb) -> 'links'
          ) as link
        from
          net_http_request
        where
          url = 'http://ward.dojo.fed.wiki/system/sitemap.json'
      )
      select
        json->>'slug' as slug,
        fedwiki_print_date(json->>'date') as updated,
        link
      from
        data
      order by
        link desc,
        updated desc nulls last
      $$ language sql
    EOQ
  }

  with "fedwiki_print_date" {
    sql = <<EOQ
      create or replace function fedwiki_print_date(date text) returns text as $$
        select to_char(to_timestamp(date::numeric / 1000), 'YYYY-MM-DD')
      $$ language sql;
    EOQ
  }

}

category "document" {
  color = "blue"
  icon = "document"
}

category "link" {
  color = "lightgray"
  icon = "link"
}