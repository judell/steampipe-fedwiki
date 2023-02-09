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

  with "fedwiki_since" {
    sql = <<EOQ
      create or replace function public.fedwiki_since(since interval) returns table (
        label text,
        value text
      ) as $$
         select
           since,
           to_char(now() - since, 'YYYY-MM-DD')
      $$ language sql
    EOQ
  }


  container {

    input "since" {
      width = 2
      title = "updated since"
      sql = <<EOQ
        with options as (
          select * from fedwiki_since(interval '1 week')
          union
          select * from fedwiki_since(interval '2 weeks')
          union
          select * from fedwiki_since(interval '1 month')
          union
          select * from fedwiki_since(interval '3 months')
          union
          select * from fedwiki_since(interval '6 months')
          union
          select * from fedwiki_since(interval '1 year')
          union
          select * from fedwiki_since(interval '2 years')
          union
          select * from fedwiki_since(interval '5 years')
        )
        select
          label,
          value
        from
          options
        order by
          value desc
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