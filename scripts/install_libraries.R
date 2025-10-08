regular.packages <- c("ape","cowplot","docopt","ggdendro","gridExtra",
                      "gggenes","ggrepel","reshape2","RColorBrewer","vegan","dplyr")

for (p in regular.packages) {
  if (!require(p, character.only = TRUE, quietly = TRUE)) {
    install.packages(p, repos = "https://cran.r-project.org")
  }
}

if (!require("ggtree", character.only = TRUE, quietly = TRUE)) {
  if (!require("BiocManager", quietly = TRUE)) install.packages("BiocManager")
  BiocManager::install("ggtree", ask = FALSE, update = FALSE)
}
