#! /bin/bash

# Create visualizations and analysis tables of timestamped routing table dumps
for d in *; do
  ( cd "$d" && sh "./AnalysisScript-T$d.sh" && echo "$d done" )
done
sh ./ConcatenateAnalysisResults.sh
sh ./CreateVisualizationsGoodOnly.sh
sh ./CopyResultData.sh
