
# fish_passage_parsnip_2021_reporting 0.1.1

  * tweaks to the executive summary
  * add a link to `fissr_explore`
  * move channel width 21b methods to methods from results
  * turn of TOC collapse

# fish_passage_parsnip_2021_reporting 0.1.0

  * Initial draft release for review.  
  * stopped tracking the pscis submission templates in repo unless changes actually happen. Used 
  
    `git update-index --assume-unchanged data/pscis_*`.  
      
  When changes actually occur we use 
  
    `git update-index --no-assume-unchanged data/pscis_*.xlsm` to log a commit
  
    `git update-index --assume-unchanged data/habitat_confirmations.xls`
