## we can switch this to pull from our own system but we will just use simons bcfishpass for now to save time
## simons db will not have the updated pscis names so we we include workflows to see that our new pscis crossings match our old modelled crossings

source('scripts/packages.R')
# source('R/functions.R')
source('scripts/private_info.R')

# conn <- DBI::dbConnect(
#   RPostgres::Postgres(),
#   dbname = dbname_wsl,
#   host = host_wsl,
#   port = port_wsl,
#   user = user_wsl,
#   password = password_wsl
# )

conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = dbname_mac,
  host = host_mac,
  port = port_mac,
  user = user_mac,
  password = password_mac
)

#
# ##listthe schemas in the database
# dbGetQuery(conn,
#            "SELECT schema_name
#            FROM information_schema.schemata")
# #
# # # ##list tables in a schema
dbGetQuery(conn,
           "SELECT table_name
           FROM information_schema.tables
           WHERE table_schema='bcfishpass'") %>%
  filter(table_name %ilike% 'prec')
# # # # # #
# # # # # # ##list column names in a table
dbGetQuery(conn,
           "SELECT column_name,data_type
           FROM information_schema.columns
           WHERE table_name='map'")


#
# dbGetQuery(conn,
#            "SELECT a.total_lakereservoir_ha
#            FROM bcfishpass.crossings a
#            WHERE stream_crossing_id IN (58159,58161,123446)")
#
# dbGetQuery(conn,
#            "SELECT o.observation_date, o.point_type_code  FROM whse_fish.fiss_fish_obsrvtn_pnt_sp o;") %>%
#   filter(observation_date > '1900-01-01' &
#          observation_date < '2021-02-01') %>%
#   group_by(point_type_code) %>%
#   summarise(min = min(observation_date, na.rm = T),
#             max = max(observation_date, na.rm = T))


# get the bcfishpass dataa for the pars


##get all the data and save it as an sqlite database as a snapshot of what is happening.  we can always hopefully update it
query <- "SELECT *
   FROM bcfishpass.crossings
   WHERE watershed_group_code IN ('PARS')"


##import and grab the coordinates - this is already done
bcfishpass<- st_read(conn, query =  query) %>%
  # st_transform(crs = 26911) %>%  #before the coordinates were switched but now they look fine...
  # mutate(
  #        easting = sf::st_coordinates(.)[,1],
  #        northing = sf::st_coordinates(.)[,2]) %>%
  st_drop_geometry() %>%
  mutate(downstream_route_measure = as.integer(downstream_route_measure))
  # dplyr::distinct(.keep_all = T) #needed to do this because there are duplicated outputs



query <- "select col_description((table_schema||'.'||table_name)::regclass::oid, ordinal_position) as column_comment,
* from information_schema.columns
WHERE table_schema = 'bcfishpass'
and table_name = 'crossings';"

bcfishpass_column_comments <- st_read(conn, query =  query) %>%
  select(column_name, column_comment)

# get the pscis data
query <- "SELECT p.*, wsg.watershed_group_code
   FROM whse_fish.pscis_assessment_svw p
   INNER JOIN whse_basemapping.fwa_watershed_groups_poly wsg
ON ST_Intersects(wsg.geom,p.geom)
WHERE wsg.watershed_group_code IN ('PARS', 'CARP', 'CRKD');"


##import and grab the coordinates - this is already done
pscis<- st_read(conn, query =  query)
# porphyryr <- st_read(conn, query =
# "SELECT * FROM bcfishpass.crossings
#    WHERE stream_crossing_id = '124487'")

dbDisconnect(conn = conn)





##this is how we update our local db.
##my time format format(Sys.time(), "%Y%m%d-%H%M%S")
# mydb <- DBI::dbConnect(RSQLite::SQLite(), "data/bcfishpass.sqlite")
conn <- rws_connect("data/bcfishpass.sqlite")
rws_list_tables(conn)
##archive the last version for now
bcfishpass_archive <- readwritesqlite::rws_read_table("bcfishpass", conn = conn)
# rws_drop_table("bcfishpass_archive", conn = conn) ##if it exists get rid of it - might be able to just change exists to T in next line
rws_write(bcfishpass_archive, exists = F, delete = TRUE,
          conn = conn, x_name = paste0("bcfishpass_archive_", format(Sys.time(), "%Y-%m-%d-%H%M")))
rws_drop_table("bcfishpass", conn = conn) ##now drop the table so you can replace it
rws_write(bcfishpass, exists = F, delete = TRUE,
          conn = conn, x_name = "bcfishpass")
rws_write(pscis, exists = F, delete = TRUE,
          conn = conn, x_name = "pscis")
# write in the xref
# rws_drop_table("xref_pscis_my_crossing_modelled", conn = conn) ##now drop the table so you can replace it
# rws_write(my_pscis_modelledcrossings_streams_xref, exists = F, delete = TRUE,
#           conn = conn, x_name = "xref_pscis_my_crossing_modelled")
# # add the comments
 # bcfishpass_column_comments_archive <- readwritesqlite::rws_read_table("bcfishpass_column_comments", conn = conn)
# rws_write(bcfishpass_column_comments_archive, exists = F, delete = TRUE,
#            conn = conn, x_name = paste0("bcfishpass_column_comments_archive_", format(Sys.time(), "%Y-%m-%d-%H%m")))
rws_drop_table("bcfishpass_column_comments", conn = conn) ##now drop the table so you can replace it
rws_write(bcfishpass_column_comments, exists = F, delete = TRUE,
          conn = conn, x_name = "bcfishpass_column_comments")
# rws_drop_table("my_pscis_modelledcrossings_streams_xref", conn = conn)
# rws_write(my_pscis_modelledcrossings_streams_xref, exists = FALSE, delete = TRUE,
#           conn = conn, x_name = "my_pscis_modelledcrossings_streams_xref")
rws_list_tables(conn)
rws_disconnect(conn)

##grab the bcfishpass spawning and rearing table and put in the database so it can be used to populate the methods and tie to the references table
urlfile="https://github.com/NewGraphEnvironment/bcfishpass/raw/pars2022ng/parameters/habitat.csv"

bcfishpass_spawn_rear_model <- read_csv(url(urlfile))


# put it in the db
conn <- rws_connect("data/bcfishpass.sqlite")
rws_list_tables(conn)
# archive <- readwritesqlite::rws_read_table("bcfishpass_spawn_rear_model", conn = conn)
# rws_write(archive, exists = F, delete = TRUE,
#           conn = conn, x_name = paste0("bcfishpass_spawn_rear_model_archive_", format(Sys.time(), "%Y-%m-%d-%H%m")))
rws_drop_table("bcfishpass_spawn_rear_model", conn = conn)
rws_write(bcfishpass_spawn_rear_model, exists = F, delete = TRUE,
          conn = conn, x_name = "bcfishpass_spawn_rear_model")
rws_list_tables(conn)
rws_disconnect(conn)
