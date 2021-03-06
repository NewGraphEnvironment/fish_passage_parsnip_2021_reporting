source('scripts/functions.R')
source('scripts/packages.R')
source('scripts/private_info.R')

# we need to use bcbarriers for now untill we get bcdata running again
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = dbname,
  host = host,
  port = port,
  user = user,
  password = password
)

# # ##list tables in a schema
dbGetQuery(conn,
           "SELECT table_name
           FROM information_schema.tables
           WHERE table_schema='whse_fish'")
# # # # #
# # # # # ##list column names in a table
dbGetQuery(conn,
           "SELECT column_name,data_type
           FROM information_schema.columns
           WHERE table_schema = 'bcfishpass'
           and table_name='streams'")

dbGetQuery(conn,
           "SELECT column_name,data_type
           FROM information_schema.columns
           WHERE table_name='fiss_fish_obsrvtn_events_sp'")

##get some stats for WCT
query = "SELECT
  fish_observation_point_id,
  s.gradient,
  s.stream_order,
  s.upstream_area_ha,
  s.channel_width,
  s.map_upstream,
  s.mad_m3s,
  e.species_code,
  e.watershed_group_code,
  round((ST_Z((ST_Dump(ST_LocateAlong(s.geom, e.downstream_route_measure))).geom))::numeric) as elevation
FROM whse_fish.fiss_fish_obsrvtn_events_sp e
INNER JOIN bcfishpass.streams s
ON e.linear_feature_id = s.linear_feature_id
WHERE e.watershed_group_code IN ('PARS');"

##e.species_code = 'WCT' AND
# unique(fiss_sum$species_code)
species_of_interest <- c('BT', 'RB', 'GR', 'KO')


fiss_sum <- st_read(conn, query = query) %>%
  filter(species_code %in% species_of_interest)

dbDisconnect(conn)
fiss_sum2 <- fiss_sum %>%
  group_by(species_code) %>%
  summarise(total_spp = n())

# get a summary of how many streams have chan width and map but no channel width



##burn it all to a file we can use later
# fiss_sum %>% readr::write_csv(file = paste0(getwd(), '/data/inputs_extracted/fiss_sum.csv'))
# fiss_sum <- readr::read_csv(file = paste0(getwd(), '/data/inputs_extracted/fiss_sum.csv'))
#
# ##lets put it in the sqlite for safekeeping
conn <- rws_connect("data/bcfishpass.sqlite")
rws_list_tables(conn)
archive <- readwritesqlite::rws_read_table("fiss_sum", conn = conn)
rws_drop_table("fiss_sum", conn = conn) ##if it exists get rid of it - might be able to just change exists to T in next line
rws_write(archive, exists = F, delete = TRUE,
          conn = conn, x_name = paste0("fiss_sum_archive_", format(Sys.time(), "%Y-%m-%d-%H%m")))
rws_write(fiss_sum, exists = F, delete = TRUE,
          conn = conn, x_name = "fiss_sum")
rws_list_tables(conn)
rws_disconnect(conn)

######################################################################################################################
######################################################################################################################
#########################################START HERE#########################################################
######################################################################################################################
######################################################################################################################

fiss_sum_grad_prep1 <- fiss_sum %>%
  mutate(Gradient = case_when(
    gradient < .03 ~ '0 - 3 %',
    gradient >= .03 &  gradient < .05 ~ '03 - 5 %',
    gradient >= .05 &  gradient < .08 ~ '05 - 8 %',
    gradient >= .08 &  gradient < .15 ~ '08 - 15 %',
    gradient >= .15 &  gradient < .22 ~ '15 - 22 %',
    gradient >= .22  ~ '22+ %')) %>%
  mutate(gradient_id = case_when(
    gradient < .03 ~ 3,
    gradient >= .03 &  gradient < .05 ~ 5,
    gradient >= .05 &  gradient < .08 ~ 8,
    gradient >= .08 &  gradient < .15 ~ 15,
    gradient >= .15 &  gradient < .22 ~ 22,
    gradient >= .22  ~ 99))

fiss_sum_grad_prep2 <- fiss_sum_grad_prep1 %>%
  group_by(species_code) %>%
  summarise(total_spp = n())

fiss_sum_grad_prep3 <- fiss_sum_grad_prep1 %>%
  group_by(species_code, Gradient, gradient_id)  %>%
  summarise(Count = n())

fiss_sum_grad <- left_join(
  fiss_sum_grad_prep3,
  fiss_sum_grad_prep2,
  by = 'species_code'
) %>%
  mutate(Percent = round(Count/total_spp * 100, 0))

##save this for the report
##burn it all to a file we can use later
fiss_sum_grad %>% readr::write_csv(file = paste0(getwd(), '/data/inputs_extracted/fiss_sum_grad.csv'))




plot_grad <- fiss_sum_grad %>%
  filter(gradient_id != 99) %>%
  ggplot(aes(x = Gradient, y = Percent)) +
  geom_bar(stat = "identity")+
  facet_wrap(~species_code, ncol = 2)+
  ggdark::dark_theme_bw(base_size = 11)+
  labs(x = "Average Stream Gradient", y = "Occurrences (%)")
plot_grad

#############################CHANNEL WIDTH######################################

fiss_sum_width_prep1 <- fiss_sum %>%
  mutate(Width = case_when(
    channel_width < 2 ~ '0 - 2m',
    channel_width >= 2 &  channel_width < 4 ~ '02 - 04m',
    channel_width >= 4 &  channel_width < 6 ~ '04 - 06m',
    channel_width >= 6 &  channel_width < 10 ~ '06 - 10m',
    channel_width >= 10 &  channel_width < 15 ~ '10 - 15m',
    # channel_width >= 15 &  channel_width < 20 ~ '15 - 20m',
    channel_width >= 15  ~ '15m+')) %>%
  mutate(width_id = case_when(
    channel_width < 2 ~ 2,
    channel_width >= 2 &  channel_width < 4 ~ 4,
    channel_width >= 4 &  channel_width < 6 ~ 6,
    channel_width >= 6 &  channel_width < 10 ~ 10,
    channel_width >= 10 &  channel_width < 15 ~ 15,
    # channel_width >= 15 &  channel_width < 20 ~ 20,
    channel_width >= 15  ~ 99))

fiss_sum_width_prep2 <- fiss_sum_width_prep1 %>%
  group_by(species_code) %>%
  summarise(total_spp = n())

fiss_sum_width_prep3 <- fiss_sum_width_prep1 %>%
  group_by(species_code, Width, width_id)  %>%
  summarise(Count = n())

fiss_sum_width <- left_join(
  fiss_sum_width_prep3,
  fiss_sum_width_prep2,
  by = 'species_code'
) %>%
  mutate(Percent = round(Count/total_spp * 100, 0))


##save this for the report
##burn it all to a file we can use later
fiss_sum_width %>% readr::write_csv(file = paste0(getwd(), '/data/inputs_extracted/fiss_sum_width.csv'))



plot_width <- fiss_sum_width %>%
  filter(!is.na(width_id)) %>%
  ggplot(aes(x = Width, y = Percent)) +
  geom_bar(stat = "identity")+
  facet_wrap(~species_code, ncol = 2)+
  ggdark::dark_theme_bw(base_size = 11)+
  labs(x = "Channel Width", y = "Occurrences (%)")
plot_width

#############WATERSHED SIZE#################################################
# bin_1 <- min(fiss_sum$upstream_area_ha, na.rm = TRUE)
fiss_sum_wshed_filter <- fiss_sum %>%
  filter(upstream_area_ha < 10000)

max(fiss_sum_wshed_filter$upstream_area_ha, na.rm = TRUE)
bin_1 <- 0
# bin_1 <- floor(min(fiss_sum_wshed_filter$upstream_area_ha, na.rm = TRUE)/5)*5
bin_n <- ceiling(max(fiss_sum_wshed_filter$upstream_area_ha, na.rm = TRUE)/5)*5
bins <- seq(bin_1,bin_n, by = 1000)

plot_wshed_hist <- ggplot(fiss_sum_wshed_filter, aes(x=upstream_area_ha
                                           # fill=alias_local_name
                                           # color = alias_local_name
)) +
  geom_histogram(breaks = bins,
                 position="identity", size = 0.75)+
  labs(x = "Upstream Watershed Area (ha)", y = "Count Fish (#)") +
  facet_wrap(~species_code, ncol = 2)+
  # scale_color_grey() +
  # scale_fill_grey() +
  theme_bw(base_size = 11)+
  scale_x_continuous(breaks = bins[seq(1, length(bins), by = 2)])+
  # scale_color_manual(values=c("grey90", "grey60", "grey30", "grey0"))+
  # theme(axis.text.x = element_text(angle = 45, hjust = 1))+
  geom_histogram(aes(y=..density..), breaks = bins, alpha=0.5,
                 position="identity", size = 0.75)
plot_wshed_hist


fiss_sum_wshed_prep1 <- fiss_sum %>%
  mutate(Watershed = case_when(
    upstream_area_ha < 2500 ~ '0 - 25km2',
    upstream_area_ha >= 2500 &  upstream_area_ha < 5000 ~ '25 - 50km2',
    upstream_area_ha >= 5000 &  upstream_area_ha < 7500 ~ '50 - 75km2',
    upstream_area_ha >= 7500 &  upstream_area_ha < 10000 ~ '75 - 100km2',
    upstream_area_ha >= 10000 ~ '100km2+')) %>%
  mutate(watershed_id = case_when(
    upstream_area_ha < 2500 ~ 2500,
    upstream_area_ha >= 2500 &  upstream_area_ha < 5000 ~ 5000,
    upstream_area_ha >= 5000 &  upstream_area_ha < 7500 ~ 7500,
    upstream_area_ha >= 7500 &  upstream_area_ha < 10000 ~ 10000,
    upstream_area_ha >= 10000  ~ 99999))




fiss_sum_wshed_prep2 <- fiss_sum_wshed_prep1 %>%
  group_by(species_code, Watershed) %>%
  summarise(count_wshd = n())

fiss_sum_wshed_prep3 <- fiss_sum_wshed_prep1 %>%
  group_by(species_code)  %>%
  summarise(total_spp = n())

fiss_sum_wshed <- left_join(
  fiss_sum_wshed_prep2,
  fiss_sum_wshed_prep3,
  by = c('species_code')
) %>%
  mutate(Percent = round(count_wshd/total_spp * 100, 0),
         Watershed = factor(Watershed, levels = c('0 - 25km2',
                                                  '25 - 50km2',
                                                  '50 - 75km2',
                                                  '75 - 100km2',
                                                  '100km2+'))
         ) %>%
  arrange(species_code, Watershed)

##save this for the report
##burn it all to a file we can use later
fiss_sum_wshed %>% readr::write_csv(file = paste0(getwd(), '/data/inputs_extracted/fiss_sum_wshed.csv'))
#

plot_wshed <- fiss_sum_wshed %>%
  filter(!is.na(Watershed)) %>%
  ggplot(aes(x = Watershed, y = Percent)) +
  geom_bar(stat = "identity")+
  facet_wrap(~species_code, ncol = 2)+
  ggdark::dark_theme_bw(base_size = 11)+
  labs(x = "Watershed Area", y = "Occurrences (%)")+
  theme(axis.text.x=element_text(angle = 45, hjust = 1))
plot_wshed


