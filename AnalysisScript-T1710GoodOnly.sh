#! /bin/bash

# Routing table dump analysis script template
BadNodes=100
GoodNodes=400
Malnodes=("A2B8F7AF60CCE9603DA1E3D4D6979E08EC5F6C53" "5DEE8C03AAB2E830EC50770C41E50793E5C19552" "99710A046E06251ECB320F3ACE9C02022F3720B6" "D0ACD745CB2569934CF1A93B306DDF7058BB157B" "CA92BCC73B25A63E41B39B4484396DDA804465E2" "9616E93B1F65AAFDAF733C5BB19B7E7DC3777112" "B3FBC69893A21DBF8E384C50D18E8DF39C3070E2" "84DE4B5B874CBF530E443235DCD6B9113D5EBEB6" "62974980F72BAB2D2C74493A2E6CC78E890A3CE1" "2DD204BDBB7508029B6011B221D81F29E6FD5ACD" "38AA9FBA57A9E1AD25F0D9FAF23D55D803BA91DF" "DF75BAA9FF13BC947078AB28F6A33107A16245FA" "27920332461728BB6222C2BFAEF78004B94A542E" "460B9C28F027247E5F3AF4984AC107211F11C06C" "1BADAB9BDECD91D435D19E4E5E0A99E092889EB7" "C24576781ADCB535AFB743A6F2AB5A04CACA0424" "64A490341FF7032F4D9AD424E3385AF39B7C66F9" "AE5AA446B6FC50B41047A67EF4D4472BDDB1BED6" "BC306D623220FA24323727CF874D810D4FE85058" "E99C3A4F1E1D8D9E2AD9DA40D2CD9E2309EFE802" "212FA9996005BD65EFFCB3180BB207CC0279E3B9" "E03F736B30B8158ABB1AF4B326DBB8267A242BBD" "083AD2158434C561D724A075262196F53EE077E5" "3897E33BE6A1D3930E5D837C4B28608807AC63A1" "E6E4C4A5C95E2FB29851D103E29177636C269DC4" "72A4B1744F9348129575B0727CEA04ECB93E6141" "6B57810999F8BE0195E669AC8DF17CCC12515CAA" "4867EE1DB3065D156BFBB0F06C32CD3B646EA152" "770985642C8DE3FE4B558A421AB28FBBAA77F006" "E8E688410D949B9F7F34A43596EF63FE5DB46F17" "4283D487BD5C079C45B5958FEDC78CE53208138E" "3F03897C7CA982EDBB623449C83E5CD1CE7E52B1" "7D6E6197D8B091F586B8E3B2CB768FD1AA87431A" "E7B5E3CFA5BCE283A4B2BF2381A29D9933F2C401" "0174B7E3354FC6C0F42E95D847582ECB813C7049" "79DEAB9B8F0DC5515EE1DCA5E0B7203BFA1DB608" "F6A8C74A6FA7EB2248CF889FDC0A30E53F379B0E" "9E835768CFCEBC93F04844A2B92CADE3920FC0C9" "192F34043B015A5E2D227AD9A5129B85BEDABBFF" "E9C951FB91502982841DFADF3C82E5862C64D54D" "FD77310524FB0FF123ACA5EBF2C72E10DB7A82AC" "98DEEBD9A650E49244EDC8B495D88DB93EB4EC3E" "E67A8457D414D556E4A403EC5660196B68259E2E" "DAAB1A9510FC18D18136BC1669F450F8016C716C" "239E5D4AAD6C5AF460838A2904198F819E9553FB" "CF9F3764EE6C695D85A8FC0DC39D252F970B334F" "85CE74878EAD25F8661579A10AB2E12850A83378" "7E0BBF4A0878CBDD0556375BF824817F25B6B3D0" "5064939DCE9CC6C71185C351D15E23D797F8FBB5" "06F070A25D71A7540F70B2F0B10906E4C3DF32BA" "4F6E858744D66FC24D6736395B8F85E94CF70870" "42F4F29DB32E090AF4F5D210FBC8055386CBAEC2" "C3E33E8EEBAD7EEA3A2B2DFA61DEA20A83AB6131" "48DC72995CB2A97D90E2BF5554E0C5F958F40AB5" "02707C5D397003B993D16F615848B1776BE19E78" "407E6CA4BEE5CEF7842FBD16CAE05A883670316F" "A2FCE567ABBE90746927F34069E77DCC2D964545" "FD2B7E90E6DF57E11755059B9F77C930DBD34E15" "802F9B77492907E9D6A3EABF5A01D0F590A9307C" "A936489E869AAD57B7DA830E42C3C57D1D1D3D4D" "858B0D298B42F9B62FA322108F4EFD4BB2C8396F" "D7ADF0DAA97C29683BB273640599D3B396C373AF" "F985528E7C28B708153D23EFD7446AE4F595EA7F" "D21A83DCE29ECA44C29CEE153E6ABE823EBB4085" "A1F0160B0E4552C9EA73B2D4C22D454CF3D216CA" "8352D5F32DFB47570E1041F4B19736422A6C8FAD" "34B3D85E740F179DCD5B88656BC1036703D81721" "5C397E7A7A0B2FB50195EA3F772ECF72ADE7C0E3" "07B5570FF069F931BC74FC427367C5515DC8FAA7" "F6551106516BE4B460E07A54CD72E36510AB8AD1" "06A024E29B10BE900B4A17232AAB7E8C55C63B6B" "F3E56252F060FEAD401C2C1F808BBF76CB090D2F" "032F5860CBC111C7ED4AC92787C1F98B15F70E1C" "B61CBD7F16B36E403DC9436743166F970AA0552E" "BA55D3B6F81F3A877C5709AB8F23B079B293763C" "41BCA720EE6EEE208B7D62D4CA50E36BEC57A992" "2F827A6384EB8995D69C9082449BA9AEB072E515" "1EF23A3BA3C957870ACD3268B3DF19A0651CEA15" "06D8D63B3A913995C3C1BD512C45536CDF50F7FE" "1C762409B0D716F92E19ABC81F22C3D60C36B57F" "5C7E1BE4F90DD503DC23709C517B185E5AD62045" "515858AD4EB5D18A6DE26BA40D04E9A78F7E8F03" "3C296DECE896DFAE159D6E0E416157973FA9E430" "97A6028299D6D9616BE1C25DCCBC6A39DCF58148" "9F56D436B6012FA128DA5B87204CE229CFCC20EB" "2E785283C396383B34BC1CC0CC2C96516A942CC9" "C6517547CA642118C539779DE80CD92AA5F24588" "0655327AFD13A9011E8AD892676E9DFD918BCBA3" "4AD951A34A0190B626C68B678D2152CAEB568120" "FBE4FED48288835E92061BA82D90DAF8ADA0CCE0" "3E1FA5379D6C0AD5A3B4ACFDBA79F02BCC54B55F" "856076BB5525DA127F611A09630BCA4352802B30" "2719839DFBB92542C6D8D417DA22D0B3201069AD" "62528162BBE289F624A3D1139A207B57B7CBD06A" "6C4EA5841861C7B6C7238653BA148E98071FE245" "9510ED215F1BAE6F37DC0A6C4896D9C3123EBE42" "70D1535413F8CFB92ABAA02C0979AA02098CE868" "B702D4F4BCCB8D1A2F105DA3E258D68A799AD08E" "D0496E1B1945EFBA8471E1BE751CE5158B708733" "67BBCB75130289DC65BB89DAB324FE34E75DE32F" )

Centernode=8E37500BAC49DEF1BAE1C6F049A20E149042B336

cp fulldump.dot fulldumpGoodOnly.dot

for j in ${Malnodes[@]}; do
sed -i '/\"'$j'\" --/d' fulldumpGoodOnly.dot
done

sed -E 's/penwidth=[0-9]+/penwidth=1/g' fulldumpGoodOnly.dot >> fulldumpGoodOnlyPenWidth1.dot

cp fulldumpGoodOnly.dot fulldumpGoodOnlyWithCenterNode.dot
sed -i '/'${Centernode}'/d' fulldumpGoodOnly.dot
sed -i '/'${Centernode}'/d' fulldumpGoodOnlyPenWidth1.dot

sfdp -x -Goverlap=scale fulldumpGoodOnly.dot | gvmap -e | neato -n2 -Tpdf > graphT1710GoodOnly.pdf
sfdp -x -Goverlap=scale fulldumpGoodOnlyPenWidth1.dot | gvmap -e | neato -n2 -Tpdf > graphT1710GoodOnlyPenWidth1.pdf
sfdp -x -Goverlap=scale fulldumpGoodOnlyWithCenterNode.dot | gvmap -e | neato -n2 -Tpdf > graphWithCenterNodeT1710GoodOnly.pdf

cp fulldumpGoodOnly.dot fulldumpAllEdgesGoodOnly.dot
cp fulldumpGoodOnlyPenWidth1.dot fulldumpAllEdgesGoodOnlyPenWidth1.dot
cp fulldumpGoodOnlyWithCenterNode.dot fulldumpAllEdgesWithCenterNodeGoodOnly.dot

sed -i -E 's/edge \[style=invis];/edge \[style=\"\"\];/' fulldumpAllEdgesGoodOnly.dot
sed -i -E 's/edge \[style=invis];/edge \[style=\"\"\];/' fulldumpAllEdgesGoodOnlyPenWidth1.dot
sed -i -E 's/edge \[style=invis];/edge \[style=\"\"\];/' fulldumpAllEdgesWithCenterNodeGoodOnly.dot

sfdp -x -Goverlap=scale fulldumpAllEdgesGoodOnly.dot | gvmap -e | neato -n2 -Tpdf > graphEdgesT1710GoodOnly.pdf
sfdp -x -Goverlap=scale fulldumpAllEdgesGoodOnlyPenWidth1.dot | gvmap -e | neato -n2 -Tpdf > graphEdgesT1710GoodOnlyPenWidth1.pdf
sfdp -x -Goverlap=scale fulldumpAllEdgesWithCenterNodeGoodOnly.dot | gvmap -e | neato -n2 -Tpdf > graphEdgesWithCenterNodeT1710GoodOnly.pdf



Lines=0
TotalLines=0
MaliciousWeights=0
TotalWeights=0

LinesWithCenterNode=0
TotalLinesWithCenterNode=0
MaliciousWeightsWithCenterNode=0
TotalWeightsWithCenterNode=0

#sed -i -E '/^$/d' fulldump.dot

for j in ${Malnodes[@]}; do
Lines=$(($Lines+$(grep ${j} fulldumpGoodOnly.dot | wc -l)))
grep -E ${j}.*weight=[0-9]+ fulldumpGoodOnly.dot >> testfileGoodOnly.txt

LinesWithCenterNode=$(($LinesWithCenterNode+$(grep ${j} fulldumpGoodOnlyWithCenterNode.dot | wc -l)))
grep -E ${j}.*weight=[0-9]+ fulldumpGoodOnlyWithCenterNode.dot >> testfileWithCenterNodeGoodOnly.txt
done

grep -E .*weight=[0-9]+ fulldumpGoodOnly.dot >> testfile2GoodOnly.txt
grep -E .*weight=[0-9]+ fulldumpGoodOnlyWithCenterNode.dot >> testfile2WithCenterNodeGoodOnly.txt

sed -i -E 's/.*weight=//g' testfileGoodOnly.txt
sed -i -E 's/\];//g' testfileGoodOnly.txt

sed -i -E 's/.*weight=//g' testfile2GoodOnly.txt
sed -i -E 's/\];//g' testfile2GoodOnly.txt

sed -i -E 's/.*weight=//g' testfileWithCenterNodeGoodOnly.txt
sed -i -E 's/\];//g' testfileWithCenterNodeGoodOnly.txt

sed -i -E 's/.*weight=//g' testfile2WithCenterNodeGoodOnly.txt
sed -i -E 's/\];//g' testfile2WithCenterNodeGoodOnly.txt

TotalLines=$(($TotalLines + $(grep "\n" fulldumpGoodOnly.dot | wc -l)))
TotalLines=$(($TotalLines - $BadNodes - 4))
echo Good Nodes: ${GoodNodes} >> AnalysisResultsGoodOnly.txt
echo Bad Nodes: ${BadNodes} >> AnalysisResultsGoodOnly.txt
echo Malicious Edges: ${Lines} >> AnalysisResultsGoodOnly.txt
echo Total Lines: ${TotalLines} >> AnalysisResultsGoodOnly.txt
MaliciousWeights=$((${MaliciousWeights} + $(( echo 0 ; sed "s/$/ +/" testfileGoodOnly.txt ; echo p ) | dc)))
echo Malicious Weights: ${MaliciousWeights} >> AnalysisResultsGoodOnly.txt
TotalWeights=$((${TotalWeights} + $(( echo 0 ; sed "s/$/ +/" testfile2GoodOnly.txt ; echo p ) | dc)))
echo Total Weights: ${TotalWeights} >> AnalysisResultsGoodOnly.txt
echo Malicious Edge Percentage: $((${Lines}*100 / ${TotalLines})) % >> AnalysisResultsGoodOnly.txt
echo MaliciousWeightPercentage: $((${MaliciousWeights}*100 / ${TotalWeights})) % >> AnalysisResultsGoodOnly.txt
echo GoodBad Node Percentage: $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) % >> AnalysisResultsGoodOnly.txt

TotalLinesWithCenterNode=$((TotalLinesWithCenterNode + $(grep "\n" fulldumpWithCenterNode.dot | wc -l)))
TotalLinesWithCenterNode=$((TotalLinesWithCenterNode - $BadNodes - 4))
echo Good Nodes With Center Node: ${GoodNodes} >> AnalysisResultsGoodOnly.txt
echo Bad Nodes With Center Node: ${BadNodes} >> AnalysisResultsGoodOnly.txt
echo Malicious Edges With Center Node: ${LinesWithCenterNode} >> AnalysisResultsGoodOnly.txt
echo Total Lines With Center Node: ${TotalLinesWithCenterNode} >> AnalysisResultsGoodOnly.txt
MaliciousWeightsWithCenterNode=$((${MaliciousWeightsWithCenterNode} + $(( echo 0 ; sed "s/$/ +/" testfileWithCenterNodeGoodOnly.txt ; echo p ) | dc)))
echo Malicious Weights With Center Node: ${MaliciousWeightsWithCenterNode} >> AnalysisResultsGoodOnly.txt
TotalWeightsWithCenterNode=$((${TotalWeightsWithCenterNode} + $(( echo 0 ; sed "s/$/ +/" testfile2WithCenterNodeGoodOnly.txt ; echo p ) | dc)))
echo Total Weights With Center Node: ${TotalWeightsWithCenterNode} >> AnalysisResultsGoodOnly.txt
echo Malicious Edge Percentage With Center Node: $((${LinesWithCenterNode}*100 / ${TotalLinesWithCenterNode})) % >> AnalysisResultsGoodOnly.txt
echo MaliciousWeightPercentage With Center Node: $((${MaliciousWeightsWithCenterNode}*100 / ${TotalWeightsWithCenterNode})) % >> AnalysisResultsGoodOnly.txt

echo \| Nodes \| Type    \| Value \| GoodNodes \| BadNodes \| MaliciousEdges \| TotalEdges \| MaliciouslWeights \| TotalWeights \| Timestamp \|>> OrgModeExportGoodOnly.txt
echo \|-------+---------+-------+-----------+----------+----------------+------------+-------------------+--------------+-\| >> OrgModeExport.txt
echo \| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \| Edges \| $((${Lines}*100 / ${TotalLines})) \| ${GoodNodes} \|  ${BadNodes} \| ${Lines} \| ${TotalLines} \| ${MaliciousWeights} \| ${TotalWeights} \| 1710 \| >> OrgModeExportGoodOnly.txt
echo \| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \| Weights \| $((${MaliciousWeights}*100 / ${TotalWeights})) \| ${GoodNodes} \|  ${BadNodes} \| ${Lines} \| ${TotalLines} \| ${MaliciousWeights} \| ${TotalWeights} \| 1710 \| >> OrgModeExportGoodOnly.txt
echo \| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \| EdgesWithCenterNode \| $((${LinesWithCenterNode}*100 / ${TotalLinesWithCenterNode})) \| ${GoodNodes} \|  ${BadNodes} \| ${LinesWithCenterNode} \| ${TotalLinesWithCenterNode} \| ${MaliciousWeightsWithCenterNode} \| ${TotalWeightsWithCenterNode} \| 1710 \| >> OrgModeExportGoodOnly.txt
echo \| $((${BadNodes}*100 / $((${GoodNodes} + ${BadNodes})))) \| WeightsWithCenterNode \| $((${MaliciousWeightsWithCenterNode}*100 / ${TotalWeightsWithCenterNode})) \| ${GoodNodes} \|  ${BadNodes} \| ${LinesWithCenterNode} \| ${TotalLinesWithCenterNode} \| ${MaliciousWeightsWithCenterNode} \| ${TotalWeightsWithCenterNode} \| 1710 \| >> OrgModeExportGoodOnly.txt

rm testfileGoodOnly.txt
rm testfile2GoodOnly.txt
rm testfileWithCenterNodeGoodOnly.txt
rm testfile2WithCenterNodeGoodOnly.txt


exit
