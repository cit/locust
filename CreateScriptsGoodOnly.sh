#! /bin/bash

# Copy good node analysis script to timestamped routing table dump folders and adjust contents for these dumps
for d in *; do
	(cd "$d" && cp ../1710/AnalysisScript-T1710GoodOnly.sh ./ && sed -i -E "s/T1710/T$d/g" AnalysisScript-T1710GoodOnly.sh && sed -i -E "s/ 1710 / ${d} /g" AnalysisScript-T1710GoodOnly.sh && mv AnalysisScript-T1710GoodOnly.sh "AnalysisScript-T${d}GoodOnly.sh" && sed -i -E "s/Malnodes=\(.*\)/$(grep 'Malnodes=\(.*\)' AnalysisScript-T${d}.sh)/g" AnalysisScript-T${d}GoodOnly.sh )  
done
