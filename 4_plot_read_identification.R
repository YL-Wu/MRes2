# 4_plot_read_identification.R
# Setup -----------------------------------------------------------------------------------------
rm(list = ls())
invisible(gc())
options(stringsAsFactors = F)

# Load libraries --------------------------------------------------------------------------------
library(dplyr)
library(ggplot2)
library(plotly)
library(htmlwidgets)

# load file ---------------------------------------------------------------
targetF <- read.table("txtfile generated by 1_readlen_qua.py", header = T, sep = "\t")
files1 <- list.files("identification results produced by 5_extract_tax_lca.sh", full.names = TRUE, pattern = "\\_final.txt$")
files2 <- list.files("identification results produced by 5_extract_tax_lca.sh", full.names = TRUE, pattern = "\\_full.txt$")
outdir <- "output folder to contain reads for flye"

# for _final.txt
col_types1 <- cols(
  name = col_character(),
  taxid = col_double(),
  superkingdom = col_character(),
  kingdom = col_character(),
  phylum = col_character(),
  class = col_character(),
  order = col_character(),
  family = col_character(),
  genus = col_character(),
  species = col_character()
)

column_names1 <- c("name", "taxid", "superkingdom", "kingdom", "phylum", "class", "order", "family", "genus", "species")
taxo_list1 <- lapply(files1, function(file) {
  read_delim(file, delim = "\t", col_names = column_names1, col_types = col_types1, skip = 1) %>%
  mutate(filename = sub("_final.txt$", "", basename(file)))
})
taxo1 <- bind_rows(taxo_list1)

# for _full.txt
col_types2 <- cols(
  .default = col_skip(),
  Read = col_character(),
  taxid = col_double(),
  taxname = col_character(),
  taxlevel = col_character(),
  identity_max = col_character(),
  identity_mean = col_character(),
  filename = col_character()
)
column_names2 <- c("Read", "taxid", "taxname", "taxlevel", "identity_max", "identity_mean", "filename")

taxo_list2 <- lapply(files2, function(file) {
  read_delim(file, delim = "\t", col_names = column_names2, col_types = col_types2, skip = 1) %>%
  mutate(filename2 = sub("_full.txt$", "", basename(file)))
})
taxo2 <- bind_rows(taxo_list2)

combined_taxo <- left_join(taxo1, taxo2, by = c("name" = "Read")) %>%
  mutate(new_barcode = str_extract(filename.y, "barcode\\d+"),
         filename = paste0(filename2, "_", new_barcode)) %>%
  select(-taxid.y, -filename.y, -filename.x, -filename2, -new_barcode)

head(combined_taxo)

taxo <- combined_taxo %>%
  mutate(kingdom = ifelse(superkingdom == "Bacteria" & is.na(kingdom), "Bacteria", kingdom),
         kingdom = ifelse(superkingdom == "Archaea" & is.na(kingdom), "Archaea", kingdom))

colnames(taxo) <- c("name",  "taxid", "superkingdom", "kingdom", "phylum", 
                    "class", "order", "family", "genus", "species",
                    "taxname", "taxlevel", "identity_max", "identity_mean", "filename")

# merge 2 df
targetF <- targetF %>%
  mutate(
    Short_Samples_Barcodes = gsub("barcode", "bc", `Samples.Barcodes.`)
  )

targetF <- targetF %>%
  mutate(Name_Combined = gsub("[ '’‘.]", "", paste0(Experiment_ID, "_", Short_Samples_Barcodes, "_", Location)))

merged_table <- targetF %>%
  left_join(taxo, by = c("Read_ID" = "name")) %>%
  select(-Experiment_ID, -Samples.Barcodes.,
         -Short_Samples_Barcodes)

# colnames(merged_table)
merged_table <- merged_table %>%
  mutate(identified = !is.na(taxid))

# add a col (Name_combined) for filename
correspondence <- data.frame(
  Name_Combined = c("LB_1_bc01_NHM0m", "LB_1_bc02_Vauxhall", "LB_1_bc03_Pimlico", "LB_1_bc04_Victoria", "LB_1_bc05_StJamessPark", "LB_1_bc06_Waterblank", "LB_1_bc07_RegentsPark", "LB_2_bc01_StMarysHospital", "LB_2_bc02_Marylebone", "LB_2_bc03_Piccadilly", "LB_2_bc04_TrafalgarSquare", "LB_2_bc05_Embankment", "LB_2_bc06_Monument", "LB_2_bc07_LiverpoolStreet", "LC_1_bc01_NHM30m", "LC_1_bc02_NHM15m", "LC_1_bc03_NHM0m", "LC_1_bc04_Vauxhall", "LC_1_bc05_Pimlico", "LC_2_bc06_Victoria", "LC_2_bc07_StJamessPark", "LC_2_bc08_RegentsPark", "LC_2_bc09_StMarysHospital", "LC_2_bc10_Marylebone", "LC_3_bc01_Embankment", "LC_3_bc02_Monument", "LC_3_bc03_LiverpoolStreet", "LC_3_bc11_Piccadilly", "LC_3_bc12_TrafalgarSquare"),
  filename = c("lp1_barcode01", "lp1_barcode02", "lp1_barcode03", "lp1_barcode04", "lp1_barcode05", "lp1_barcode06", "lp1_barcode07", "lp2_barcode01", "lp2_barcode02", "lp2_barcode03", "lp2_barcode04", "lp2_barcode05", "lp2_barcode06", "lp2_barcode07", "pool1_barcode01", "pool1_barcode02", "pool1_barcode03", "pool1_barcode04", "pool1_barcode05", "pool2_barcode06", "pool2_barcode07", "pool2_barcode08", "pool2_barcode09", "pool2_barcode10", "pool3_barcode01", "pool3_barcode02", "pool3_barcode03", "pool3_barcode11", "pool3_barcode12")
)

get_name_combined <- function(filename) {
  if (is.na(filename)) {
    return(NA)
  }
  match <- correspondence$Name_Combined[correspondence$filename == filename]
  if (length(match) == 0) {
    return(NA)
  }
  return(match)
}

taxo$Name_Combined <- sapply(taxo$filename, get_name_combined)
write.table(taxo, "0_summary_taxo.txt", row.names = FALSE, quote = F, sep="\t")

summary_stats <- merged_table %>%
  group_by(Name_Combined) %>%
  summarise(
    Total_Reads = n(),
    Identified_Reads = sum(identified, na.rm = TRUE),
    Unidentified = Total_Reads - Identified_Reads,
    Proportion_Identified = Identified_Reads / Total_Reads
  ) %>%
  arrange(desc(Total_Reads))

write.table(summary_stats, "0_summary_idstats.txt", row.names = FALSE, quote = F, sep="\t")

colors <- c("NHM 30m" = "#e31a1c", "NHM 15m" = "#e31a1c", "NHM 0m" = "#e31a1c", 
            "Vauxhall" = "#ff7f00", "Pimlico" = "#fdbf6f",
            "Victoria" = "#F4D03F", "St. James’s Park" = "#ffff99", "Water blank" = "#99A3A4",
            "Regent’s Park" = "#33a02c", "St. Mary’s Hospital" = "#b2df8a", "Marylebone" = "#48C9B0",
            "Piccadilly" = "#1f78b4", "Trafalgar Square" = "#a6cee3", "Embankment" = "#6a3d9a",
            "Monument" = "#cab2d6", "Liverpool Street" = "#F2A6C9")

# len and qua --------------------------------------------------------
hist_data <- merged_table %>%
  mutate(bin = cut(Read_length, breaks = seq(0, max(Read_length)+100, by = 100), 
                   include.lowest = TRUE, right = FALSE, dig.lab = 10)) %>%
  group_by(Name_Combined, identified, bin) %>%
  summarise(n = n(), .groups = 'drop') %>%
  group_by(Name_Combined, identified) %>%
  mutate(Prop_status_sample = n / sum(n)) %>%
  ungroup()

peak_data <- hist_data %>%
  group_by(Name_Combined, identified) %>%
  filter(Prop_status_sample == max(Prop_status_sample)) %>%
  ungroup()
# merge with taxo_read_length later

plot_histogram_length1 <- ggplot(merged_table, aes(x = Read_length, fill = identified)) +
  geom_histogram(alpha = 0.7, position = "stack", binwidth = 100) +
  facet_wrap(~Location+Name_Combined, scales = "free_y") +
  theme_classic() +
  labs(title = "Read Length Distribution and Identification Status (LC-2019, LB-2021)",
       x = "Read Length (bp)", 
       y = "Count",
       fill = "Identified") +
  scale_fill_manual(values = c("TRUE" = "#229954", "FALSE" = "#F1C40F"),
                    labels = c("TRUE" = "Yes", "FALSE" = "No")) +
  scale_x_continuous(limits = c(0, 5000), breaks = seq(0, 5000, by = 1000)) +
  theme(legend.position = "top",
        strip.background = element_blank(),
        strip.text = element_text(face = "bold"))

plot_histogram_interactive <- ggplotly(plot_histogram_length1)
saveWidget(plot_histogram_interactive, "3_len_histogram.html")
ggsave("3_len_histogram.pdf", plot = plot_histogram_length1, width = 20, height = 16)

plot_density_length2 <- ggplot(merged_table, aes(x = Read_length, fill = identified)) +
  geom_density(alpha = 0.5) +
  facet_wrap(~ Location + Name_Combined, scales = "free_y") +  # Facet by both Location and Name_Combined
  theme_classic() +
  labs(title = "Read Length Density with Identification Status (LC-2019,LB-2021)", x = "Read Length (bp)", y = "Density") +
  scale_fill_manual(values = c("TRUE" = "#229954", "FALSE" = "#F1C40F"),
                    labels = c("TRUE" = "Yes", "FALSE" = "No")) +
  scale_x_continuous(limits = c(0, 5000), breaks = seq(0, 5000, by = 1000)) +
  theme(legend.position = "top",
        strip.background = element_blank(),
        strip.text = element_text(face = "bold"))
ggsave("3_len_density.pdf", plot = plot_density_length2, width = 20, height = 16)


# quality
plot_histogram_qua <- ggplot(merged_table, aes(x = Read_quality, fill = identified)) +
  geom_histogram(alpha = 0.7, position = "stack") +
  facet_wrap(~Location+Name_Combined, scales = "free_y") +
  theme_classic() +
  labs(title = "Read quality Distribution and Identification Status (LC-2019, LB-2021)",
       x = "Read Quality", 
       y = "Count",
       fill = "Identified") +
  scale_fill_manual(values = c("TRUE" = "#229954", "FALSE" = "#F1C40F"),
                    labels = c("TRUE" = "Yes", "FALSE" = "No")) +
  theme(legend.position = "top",
        strip.background = element_blank(),
        strip.text = element_text(face = "bold"))
plot_histogram_qua_interactive <- ggplotly(plot_histogram_qua)
saveWidget(plot_histogram_qua_interactive, "len_histogram.html")
ggsave("3_qua_histogram.pdf", plot = plot_histogram_qua, width = 20, height = 16)

plot_density_quality <- ggplot(merged_table, aes(x = Read_quality, fill = identified)) +
  geom_density(alpha = 0.5) +
  facet_wrap(~ Location + Name_Combined, scales = "free_y") +
  theme_classic() +
  labs(title = "Read quality Density with Identification Status (LC-2019,LB-2021)", x = "Read Quality", y = "Density") +
  scale_fill_manual(values = c("TRUE" = "#229954", "FALSE" = "#F1C40F"),
                    labels = c("TRUE" = "Yes", "FALSE" = "No")) +
  theme(legend.position = "top",
        strip.background = element_blank(),
        strip.text = element_text(face = "bold"))
ggsave("3_qua_density.pdf", plot = plot_density_quality, width = 20, height = 16)

print("finish hist+density")


# wilcox.test -------------------------------------------------------------
names_combined <- unique(merged_table$Name_Combined)
result_df <- data.frame(Name_Combined = character(length(names_combined)), 
                        true_count = integer(length(names_combined)),
                        false_count = integer(length(names_combined)),
                        p_value = numeric(length(names_combined)), 
                        stringsAsFactors = FALSE)

for (i in seq_along(names_combined)) {
  name <- names_combined[i]
  name_data <- merged_table %>% filter(Name_Combined == name)
  true_count <- sum(name_data$identified == TRUE)
  false_count <- sum(name_data$identified == FALSE)
  if (length(unique(name_data$identified)) == 2) {
    p_value <- wilcox.test(Read_length ~ identified, data = name_data, exact = FALSE)$p.value
  } else {
    p_value <- NA
  }
  result_df[i, ] <- data.frame(Name_Combined = name, 
                               true_count = true_count,
                               false_count = false_count,
                               p_value = p_value)
}
result_df <- result_df %>%
  mutate(log_p_value = -log10(p_value)) %>%
  filter(!is.na(p_value))
result_df <- result_df %>%
  mutate(star_label = case_when(
    p_value <= 0.0001 ~ "****",
    p_value <= 0.001 ~ "***",
    p_value <= 0.01 ~ "**",
    p_value <= 0.05 ~ "*",
    TRUE ~ "ns"
  ))
write.csv(result_df, "4_result_wilcox.csv", row.names = FALSE, quote = F)

merged_table_box <- merged_table %>%
  left_join(result_df, by = "Name_Combined") %>%
  filter(!is.na(p_value)) %>%
  filter(Read_length <= 5000)

# boxplot+star
plot_len_box <- ggplot(merged_table_box, aes(x = as.factor(identified), y = Read_length, fill = as.factor(identified))) +
  geom_boxplot() +
  facet_wrap(~Location+Name_Combined, scales = "fixed", ncol = 6) +
  labs(title = "Read Length Boxplot with Identification Status", x = "Identification Status", y = "Read Length (bp)") +
  theme(legend.position = "none") +
  theme_classic() +
  scale_fill_manual(values = c("TRUE" = "#229954", "FALSE" = "#F1C40F"),
                    labels = c("TRUE" = "Yes", "FALSE" = "No")) +
  theme(legend.position = "top",
        strip.background = element_blank()) +
  scale_y_continuous(limits = c(0, 6000))
ggsave("4_len_box_wilcox.png", plot = plot_len_box, width = 20, height = 16)
plot_len_box_interactive <- ggplotly(plot_len_box)
saveWidget(plot_len_box_interactive, "plot_len_box_interactive.html")

print("finish wilcox test")


# avg. read length/quality for each sample --------------------------------
taxo_read_length <- merged_table %>%
  group_by(Name_Combined, identified) %>%
  summarise(avg_read_length = mean(Read_length, na.rm = TRUE),
            avg_read_quality = mean(Read_quality, na.rm = TRUE),
            count = n()) %>%
  ungroup()

merged_out <- peak_data %>%
  left_join(taxo_read_length, by = c("Name_Combined", "identified")) %>%
  select(-Prop_status_sample)

merged_out2 <- merged_out %>%
  left_join(medians, by = c("Name_Combined", "identified")) %>%
  select(-count.y)

colnames(merged_out2) <- c("Sample", "identified", "highestAbundance_bin", "highestAbundance_count",
                           "avg_read_length", "avg_read_quality", "identified_count", "Location", "median_read_length")
write.csv(merged_out2, "0_stats_id_read.csv", row.names = FALSE, quote = F)

print("finish 0_stats_id_read.csv")


# extract synthetic -----------------------------------------------------------
counts <- merged_table %>%
  group_by(Name_Combined) %>%
  summarise(
    synthetic_count = sum(str_detect(species, "synthetic"), na.rm = T),  # 计算包含"synthetic"的记录数
    identified_count = sum(identified == "TRUE"),  # 计算identified为TRUE的记录数
    proportion = ifelse(identified_count > 0, (synthetic_count / identified_count) * 100, 0),  # 计算占比
    unique_taxid_synthetic = paste(unique(taxid[str_detect(species, "synthetic")]), collapse = "; "),
    .groups = 'drop'
  )

write.csv(counts, "0_counts_synthetic.csv", row.names = FALSE, quote = F)
print("finish synthetic")

# extract false -----------------------------------------------------------
false_ta <- merged_table %>%
  filter(identified == "FALSE")

groups <- split(false_ta, list(false_ta$Name_Combined, false_ta$Fastq))

lapply(names(groups), function(group) {
  group_data <- groups[[group]]
  
  folder_name <- unique(group_data$Name_Combined)
  fastq_name <- unique(group_data$Fastq)
  
  if (length(folder_name) > 0 && length(fastq_name) > 0) {
    dir_path <- file.path(outdir, folder_name)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
    }
    file_path <- file.path(dir_path, paste0(fastq_name, ".txt"))
    
    writeLines(group_data$Read_ID, file_path)
  }
})

print("finish txt files")

