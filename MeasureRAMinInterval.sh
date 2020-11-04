#! /bin/bash

# Measure performance data in intervals on linux
nrofnodes=${1}
expname=${2}
time=${3}
first=${4}
filenameProc=${5}
filenamePidstat=${6}
filenameTop=${7}

time=${8}
pid=${9}
timeInterval=${10}
nrtotal=${11}
nrbenign=${12}
nrmalicious=${13}
waittime=5

if [ $first -eq 1 ]; then
  echo \|Nodes\|Time\|TimeInterval\|NrNodesTotalCurrent\|NrNodesBenignCurrent\|NrNodesMaliciousCurrent\|VmHWM\|VmSwap\|VmPeak\|VmSize\|VmData\|RssAnon\|RssFile\|RssShmem\| >> ${filenameProc}
  echo \|-+-+-+-+-+-+-+-+-+-+-+-+-+-\| >> ${filenameProc}

  echo \|Nodes\|Time\|TimeInterval\|NrNodesTotalCurrent\|NrNodesBenignCurrent\|NrNodesMaliciousCurrent\|TimeEpoch\|CpuUser\|CpuSystem\|CpuTime\|minflts\|majflts\|vsz\|rss\|mem\|kbrds\|kbwrs\|iodelay\| >> ${filenamePidstat}
  echo \|-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-\| >> ${filenamePidstat}

  echo \|Nodes\|Time\|TimeInterval\|NrNodesTotalCurrent\|NrNodesBenignCurrent\|NrNodesMaliciousCurrent\|TimeEpoch\|VirtRam\|CpuTime\|RamPercent\| >> ${filenameTop}
  echo \|-+-+-+-+-+-+-+-+-+-\| >> ${filenameTop}
fi
    
if [ $first -eq 2 ]; then
    echo \|${nrofnodes}\|${time}\|${timeInterval}\|${nrtotal}\|${nrbenign}\|${nrmalicious}\|$(grep VmHWM /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep VmSwap /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep VmPeak /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep VmSize /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep VmData /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep RssAnon /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep RssFile /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\|$(grep RssShmem /proc/${pid}/status | awk -v OFS="|" '{print $2; fflush()}')\| >> ${filenameProc}
    
    echo $(pidstat -d -H -p ${pid} -r -u -v -w -h -T TASK | awk -v OFS="|" '$1+0>0 {print "",'${nrofnodes}','${time}','${timeInterval}','${nrtotal}','${nrbenign}','${nrmalicious}',strftime("%s"),$4,$5,$8,$10,$11,$12,$13,$14,$15,$16,$18,""; fflush()}') >> ${filenamePidstat}
    
    echo $(top -b -d ${waittime} -n 1 -E k -p ${pid} | awk -v OFS="|" '$1+0>0 {print "",'${nrofnodes}','${time}','${timeInterval}','${nrtotal}','${nrbenign}','${nrmalicious}',strftime("%s"),$5,$9,$10,""; fflush()}') >> ${filenameTop}
fi

if [ $first -eq 3 ]; then
  sed -i -E 's/,/\./g' ${filenameProc}
  sed -i -E 's/,/\./g' ${filenamePidstat}
  sed -i -E 's/,/\./g' ${filenameTop}
fi
