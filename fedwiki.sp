dashboard "fedwiki" {

  with "fedwiki_data" {
    sql = <<EOQ
      create or replace function public.fedwiki_data() returns table (
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
        json->>'slug',
        to_char(to_timestamp( (json->>'date')::numeric / 1000), 'YYYY-MM-DD'),
        link
      from
        data
      $$ language sql
    EOQ
  }

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

      chart {
        type = "donut"
        width = 4
        title = "ward.dojo.fed.wiki link counts"
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

      table {
        width = 4
        title = "ward.dojo.fed.wiki links by update"
        args = [ self.input.limit.value ]
        sql = <<EOQ
          select
            slug,
            link,
            updated
          from
            fedwiki_data()
          order by
            updated desc nulls last
          limit $1
        EOQ
      }

    }

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