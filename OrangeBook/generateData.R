library(faosws)
library(data.table)

if(Sys.info()[7] == "josh"){ # Josh Work
    workingDir = "~/Documents/Github/privateFAO/OrangeBook/"
    GetTestEnvironment(
      baseUrl = "https://hqlprswsas1.hq.un.fao.org:8181/sws",
      token = "bb7873a0-2c21-46ae-ac42-4ed430ebda7c"
      #     baseUrl = "https://hqlqasws1.hq.un.fao.org:8181/sws",
      #     token = "7fe7cbec-2346-46de-9a3a-8437eca18e2a" #Michael's token
    )
} else if(Sys.info()[7] %in% c("browningj", "rockc_000")){ # Josh virtual & home
    workingDir = "~/Github/privateFAO/OrangeBook/"
    GetTestEnvironment(
      baseUrl = "https://hqlprswsas1.hq.un.fao.org:8181/sws",
      token = "2789cc75-120e-4963-9694-41c4bcf67814"
      #     baseUrl = "https://hqlqasws1.hq.un.fao.org:8181/sws",
      #     token = "7fe7cbec-2346-46de-9a3a-8437eca18e2a" #Michael's token
    )
} else if(Sys.info()[7] == "Golini"){ # Nata work
  workingDir = "~/Github/privateFAO/OrangeBook/"
  GetTestEnvironment(
    baseUrl = "https://hqlprswsas1.hq.un.fao.org:8181/sws",
    token = "030e170a-3a35-4c77-acda-be89feb1c6e2" # Nata's token
  )
} else {
  stop("No working dir for current user!")
}

wheatKeys = c("0111", "23110", "23140.01", "23140.02", "23140.03", "23220.01",
              "23220.02", "23490.02", "23710", "39120.01", "F0020", "F0022")
cattleKeys = c("02111", "21111.01", "21111.02", "21182", "21184.01", "21185",
               "21512.01", "23991.04", "F0875")
palmOilKeys = c("01491.01", "01491.02", "2165", "21691.14", "21910.06", "21700.01",
                "21700.02", "F1243", "34550", "F1275", "34120", "F2199", "21545",
                "21535")
sugarKeys = c("01802", "23512", "F7156", "23210.04", "2351", "23511", "23520",
              "23540", "23670.01", "24110", "2413", "24131", "24139",
              "24490.92", "39140.02", "F7157", "01801", "39140.01", "F7161",
              "01809", "F7162", "F7163")
milkKeys = c("02211", "22120", "22130.01", "22130.02", "22130.03", "22211", 
             "22212", "22221.01", "22221.02", "22222.01", "22222.02", "22230.01", "22230.02", "22230.03", "22230.04",
             "22241.01", "22241.02", "22251.01", "22251.02", "22251.03", "22251.04", "22260", "23210.06")

## NATA: milkKeys = c("222110.01","222110.02", "222110.03") are not in the SWS

###############################################################################
# Non-trade Data                                                              #
###############################################################################

key = DatasetKey(
    domain = "agriculture",
    dataset = "agriculture",
    dimensions = list(
        ## All countries (needed for models)
        Dimension(name = "geographicAreaM49",
                  keys = GetCodeList("agriculture", "agriculture",
                                     "geographicAreaM49")[type == "country", code]),
        Dimension(name = "measuredElement", keys = c("5113", "5025", "5312", "5510", "5421",
                                                     "5520", "5525", "5023", "5327", "5016",
                                                     "5141", "5120",
                                                     # Cattle: head, carcass weight, born
                                                     "5031", "5417", "5514")),
        Dimension(name = "measuredItemCPC", keys = c(wheatKeys, cattleKeys,
                                                     palmOilKeys, sugarKeys, milkKeys)),
        ## 15 years
        Dimension(name = "timePointYears", keys = as.character(1996:2011))
    ))
pivoting = list(Pivoting(code = "geographicAreaM49"),
                Pivoting(code = "timePointYears"),
                Pivoting(code = "measuredItemCPC"),
                Pivoting(code = "measuredElement"))
data = GetData(key, normalized = FALSE, pivoting = pivoting)
data[, Value_measuredElement_5141 := as.numeric(Value_measuredElement_5141)]

###############################################################################
# Trade Data                                                                  #
###############################################################################

# partnerCountry = GetCodeList(domain = "trade", dataset = "ct_raw_tf",
#                              dimension = "partnerCountryM49")[type == "country", code]
partnerCountry = "0" # World
map = GetTableData(schemaName = "ess", tableName = "hs_2_cpc")
hsKeys = map[cpc %in% gsub("\\..*", "", c(wheatKeys, cattleKeys,
                                          palmOilKeys, sugarKeys, milkKeys)),
             unique(hs)]
key = DatasetKey(
    domain = "trade",
    dataset = "ct_raw_tf",
    dimensions = list(
        Dimension(name = "reportingCountryM49", keys = "842"),
        Dimension(name = "partnerCountryM49", keys = partnerCountry),
        Dimension(name = "measuredElementTrade", keys = c("5600", "5900")),
        Dimension(name = "measuredItemHS", keys = hsKeys),
        Dimension(name = "timePointYears", keys = "2011")
    ))
tradeData = GetData(key)
tradeData[, partnerCountryM49 := NULL]
setnames(tradeData, c("measuredItemHS", "reportingCountryM49"),
         c("hs", "geographicAreaM49"))

## Map codes to HS, scale values with split factors
tradeData = merge(tradeData, map, by = "hs")
## Aggregate "crude" and "refined" palm oil to just palm oil.
tradeData[hs %in% c("151110", "151190"), cpc := "2165"]
tradeData[, Value := Value * split]
tradeData[, c("hs", "split", "conversion_factor") := NULL]
tradeData = dcast.data.table(data = tradeData,
    formula = cpc + geographicAreaM49 + timePointYears ~ measuredElementTrade,
    value.var = "Value", fun.aggregate = sum)
setnames(tradeData, c("5600", "5900"), c("Value_measuredElement_5600",
                                         "Value_measuredElement_5900"))
## Agriculture/Agriculture has US as 840, trade has it as 842.  No idea why...
tradeData[, geographicAreaM49 := "840"]
## Value's are 1000x bigger than equivalent values from agriculture/agriculture
tradeData[, c("Value_measuredElement_5600", "Value_measuredElement_5900") :=
              list(Value_measuredElement_5600/1000, Value_measuredElement_5900/1000)]

###############################################################################
# Merge the trade data                                                        #
###############################################################################

key = c("cpc", "timePointYears", "geographicAreaM49")

## Allocate split values arbitrarily
## Define a merge key for data
data[, cpc := gsub("\\..*", "", measuredItemCPC)]
data = merge(data, tradeData, by = key, all = TRUE)
## Allocate splits randomly
data[, splitProp := abs(rnorm(.N)), by = c(key)]
data[, Value_measuredElement_5600 := Value_measuredElement_5600 *
         splitProp/sum(splitProp), by = c(key)]
data[, splitProp := abs(rnorm(.N)), by = c(key)]
data[, Value_measuredElement_5900 := Value_measuredElement_5900 *
         splitProp/sum(splitProp), by = c(key)]
data[, splitProp := NULL]
data[, cpc := NULL]

write.csv(data, file = paste0(workingDir, "standardizationData.csv"),
          row.names = FALSE)

###############################################################################
# Commodity trees                                                             #
###############################################################################

load(paste0(workingDir, "../../faoswsAupus/data/commodityTrees.RData"))
suaTree[, parentID := faoswsUtil::fcl2cpc(formatC(parentID, width = 4, flag = "0"))]
suaTree[, childID := faoswsUtil::fcl2cpc(formatC(childID, width = 4, flag = "0"))]
cpcCodes = data[!is.na(measuredItemCPC), unique(measuredItemCPC)]
suaTree = suaTree[childID %in% cpcCodes | parentID %in% cpcCodes, ]
suaTree[, groupID := paste0(parentID, "-", childID)]
suaTree[parentID == "0111" & childID %in% c("23110", "39120.01", "23140.01"),
        groupID := "0111-23110"]
suaTree[parentID == "21111.01" & childID %in% c("21111.02", "21512.01"),
        groupID := "21111.01-21111.02"]
## Manually adjust some values, in particular to prevent infinite rates
suaTree[parentID == "0111" & childID == "23140.01", extractionRate := 0.06]
suaTree[parentID == "0111" & childID == "39120.01", extractionRate := 0.22]
## Update sugar extraction rates
suaTree[parentID == "01801" & childID == "23512", extractionRate := 0.14]
suaTree[parentID == "01801" & childID == "23540",
        c("extractionRate", "target") := list(0.04, "F")]
suaTree[parentID == "01801" & childID == "39140.01",
        c("extractionRate", "target") := list(0.07, "F")]
suaTree[parentID == "01801", groupID := "01801-23512"]
suaTree[parentID == "01802" & childID == "23511.01", extractionRate := 0.11]
suaTree[parentID == "01802" & childID == "23540",
        c("extractionRate", "target") := list(0.05, "F")]
suaTree[parentID == "01802" & childID == "39140.02",
        c("extractionRate", "target") := list(0.25, "F")]
suaTree[parentID == "01802" & childID %in% c("23511.01", "23540", "39140.02"),
        groupID := "01802-23511.01"]
## If processing forward, shares will be required
suaTree[target == "F", share := 1]

write.csv(suaTree, file = paste0(workingDir, "standardizationTree.csv"),
          row.names = FALSE)

###############################################################################
# Share trees                                                                 #
###############################################################################

files = dir(paste0(workingDir, "../../faoswsAupus/R"), full.names = TRUE)
sapply(files, source)

# aupusParam = getAupusParameter(areaCode = "231", assignGlobal = FALSE,
#                                yearsToUse = 2011)
# shareData = getShareData(aupusParam = aupusParam, database = "new")
# shareData = collapseSpecificData(aupusParam = aupusParam, listData = shareData)
# write.csv(shareData, file = paste0(workingDir, "shareData.csv"))

shareData = data.table(measuredItemParentFS = c("0111", "0111", "0111", "0111", "0111"),
                       measuredItemChildFS = c(23110, 39120.01, 23140.01, 23140.02, 23140.03),
                       Value_share = c(95, 95, 95, 1, 4),
                       groupID = c(1, 1, 1, 2, 3))
shareData = rbind(shareData,
    data.table(
        measuredItemParentFS = c(21111.01, 21111.01, 21111.01, 21111.01, 21111.01, 21111.01, 21111.01),
        measuredItemChildFS = c(21111.02, 21512.01, 21182, 21185, 21184.01, "F0875", 23911.04),
        Value_share = c(40, 40, 10, 10, 10, 10, 20),
        groupID = c(1, 1, 2, 3, 4, 5, 6)
    ))
shareData = rbind(shareData,
    data.table(
        measuredItemParentFS = c(2165, 2165),
        measuredItemChildFS = c(34120, 21932.02),
        Value_share = c(50, 50),
        groupID = c(1, 2)
    ))

write.csv(shareData, file = paste0(workingDir, "shareData.csv"), row.names = FALSE)