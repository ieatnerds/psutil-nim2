# This is the start of a second psutil implementation in nim,
# hopefully I can get it fully developed and on feature parity for all
# systems

# A huge thank you to John scillieri for his original implementation
# as well as his vital help in creating a new one.

# Imports
import
  strutils, os, times,
  terminal, typetraits, strformat,
  sysconf, sets, tables,
  net, math, algorithm,
  posix, sequtils

# Constants: out of personal preference I've decided to start with lowercase letters
let
  statFile = "/proc/stat"
  clockTicks = sysconf( SC_CLK_TCK )
  pageSize = sysconf( SC_PAGE_SIZE )

# Data Types
type
  # Note: According to several sources iowait is unreliable and usually inaccurate
  CpuTime = tuple[user: float, nice: float, system: float, idle: float, iowait: float, irq: float, softirq: float,
  steal: float, guest: float, guestNice: float]

# Procedures
proc bootTime*(): float =
  ## Return the system boot time expressed in seconds since the epoch
  # only mildly edited from john scillieri's implemntation
  let stat_path = statFile
    for line in stat_path.lines:
      if startswith(line, "btime"):
        return parseFloat(split(stripWhitespace(line))[1]) # hope that works out properly, changed for consistency, admittedly, maybe less readable
  
    raise newException(OSError, "line 'btime' not found in $1" % stat_path)

proc createTime(self: Process):
  
  values = parseStatFile(self)
  bt = boot_time()
  return int(parseFloat(values[20])) / clockTicks + bt

proc parseCpuTimeLine(test: string): CpuTime =
  # This procedure is a much more efficient way of creating a CpuTime then my previous way
  let
    values = text.splitWhitespace()
    let times = mapIt(values[1..<len(values)], parseFloat(it) / clockTicks.float) # must be a more consistent approach
    
  if len(times) >= 7:
    for i in 0..<7: # I believe this should work fine, fingers crossed
      result[i] = times[i]
  if len(times) >= 8:
    result.steal = times[7]
  if len(times) >= 9:
    result.guest = times[8]
  if len(times) >= 10:
    result.guest_nice = times[9]


proc cpuTimes():
  # just as the cpu_times function works in psutil we will return a tuple on the cpu times
  # the type returned is defined at the head of this file as cpuTime.
  #
  # Note: According to several sources, iowait is unreliable and inaccurate
  # Also not every field is available on every system.
  for line in lines(statFile):
    result = parseCpuTimeLine(line)
    break


proc getCpuUsage(): float =
  # This procedure works on retrieving info from /proc/stat twice and calculating the average cpu
  # usage over the past ~1 second. using time on my machine comes out to 1.003 real seconds pretty 
  # evenly no matter when I run it

  # Apologies for the extreme spagheti code
  # I'm already aware of several fixes 

  var 
    statFile1: File
    statFile2: File
    statLine1: string
    statLine2: string
    totalSec = 0
    idle1: int
    idle2: int
    totIdle: int
    i = 0 # see about not using this i at all

  statFile1 = open(stat)

  for line in statFile1.lines:
    if i == 0:
      statLine1 = line
      inc(i)
    else:
      break
  
  sleep(1000)

  statFile2 = open(stat)

  # fix use of this i
  i = 0

  for line in statFile2.lines:
    if i == 0:
      statLine2 = line
      inc(i)
    else:
      break

  for value in statLine2.splitWhitespace():
    try:
      var temp = parseInt(value)
      totalSec += temp
    except:
      continue

  for value in statLine1.splitWhitespace():
    try:
      var temp = parseInt(value)
      totalSec -= temp
    except:
      continue
  
  # fix use of this i
  i = 0

  for value in statLine1.splitWhitespace():
    if i == 4:
      idle1 = parseInt(value)
      inc(i)
    else:
      inc(i)
  
  # fix use of this i
  i = 0

  for value in statLine2.splitWhitespace():
    if i == 4:
      idle2 = parseInt(value)
      inc(i)
    else:
      inc(i)

  totIdle = idle2 - idle1
  
  var usage = 100 - ((totIdle * 100) / totalSec)

  return usage

when isMainModule:
  echo getCpuUsage()
  echo bootTime()
