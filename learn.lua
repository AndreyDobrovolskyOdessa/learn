#!/usr/bin/env lua

local freqInit = 256
local isLearnt = 3

local dict = {}

local ReadDict = function(dictName)

  local func = loadfile(dictName)
  if not func then
    io.write("Error loading ", dictName, "\n")
    os.exit(1)
  end

  local newDict = func()

  if type(newDict) ~= "table" then
    io.write("No table defined in ", dictName, "\n")
    os.exit(1)
  end

  for original,equivalent in pairs(newDict) do
    if type(equivalent) ~= "table" then
      newDict[original] = {equivalent}
    end

    for i,value in ipairs(newDict[original]) do
      if type(value) ~= "table" then
        newDict[original][i] = {value}
      end
      local description = newDict[original][i]
      if type(description[1]) ~= "string" then
        io.write("Missing string for ", original, " ", tostring(i))
        os.exit(1)
      end
      for j=2,4 do
        description[j] = description[j] or 0
      end
      description[5] = description[5] or freqInit
      for j=2,5 do
        if type(description[j]) ~= "number" then
          io.write("Wrong type for ", original, " ", tostring(i), " ", tostring(j))
          os.exit(1)
        end
      end
    end
  end

  for original,equivalent in pairs(newDict) do
    dict[original] = newDict[original]
  end

end

local saveName = "learn.save"

if #arg == 0 then
  ReadDict(saveName)
else
  for i,dictName in ipairs(arg) do
    ReadDict(dictName)
  end
end


local dictLen = 0

for i,j in pairs(dict) do dictLen = dictLen + 1 end

if dictLen < 2 then
  io.write("Dictionary size must be >2.\n")
  os.exit(1)
end


math.randomseed(os.time())

local previousOriginal = nil

local OriginalFreq = function(equivalent)
  local freq = 0
  for i,j in ipairs(equivalent) do
    if j[5] > freq then freq = j[5] end
  end
  return freq
end


while true do

  local freqTotal = 0

  for i,j in pairs(dict) do
    if i ~= previousOriginal then
      freqTotal = freqTotal + OriginalFreq(j)
    end
  end

  local randomN = math.random()

  local freq = 0
  local original

  for i,j in pairs(dict) do
    if i ~= previousOriginal then
      freq = freq + OriginalFreq(j)
      if freq / freqTotal >= randomN then
        original = i
        previousOriginal = original
        for x,y in ipairs(j) do
          y[2] = y[2] + 1
        end
        break
      end
    end
  end

  os.execute("clear")

  io.write("Original : ", original, "\n\nYour equivalent (delimiter is ;) : ")

  local answers = io.read("l")
  local answer = {}

  for w in string.gmatch(answers,"[^;]+") do
    local ww = string.match(w,"%s*(.*[^%s])%s*") -- cut leading and trailing spaces
    ww = string.gsub(ww,"%s+"," ")  -- squeeze spaces
    answer[ww] = false
  end

  local answerCorrect = true

  for w,x in pairs(answer) do
    for i,j in ipairs(dict[original]) do
      if w == j[1] then
        j[3] = j[3] + 1
        j[4] = j[4] + 1
        j[5] = j[5] // 2
        answer[w] = true
        break
      end
    end
    if not answer[w] then answerCorrect = false end
  end

  if not answerCorrect then
    for i,j in ipairs(dict[original]) do
      j[4] = 0
      j[5] = dictLen * freqInit
    end
  end

  io.write("\nResult : ")
  for w,correct in pairs(answer) do
    io.write(w, correct and " + " or " - ","; ")
  end
  io.write("\n\n")

  io.write("Correct : ")

  for i,j in ipairs(dict[original]) do
    io.write(j[1]," ; ")
  end
  io.write("\n\n")

  local areLearnt = 0

  for i,j in pairs(dict) do
    for x,y in ipairs(j) do
      if y[4] >= isLearnt then
        areLearnt = areLearnt + 1
      end
    end
  end

  io.write("Are learnt : ", tostring(areLearnt),"\n\n")


  if areLearnt >= dictLen then
    io.write("Done!\n\n")
    break
  end


  io.write("Once again? [Y/n] : ")
  if io.read() == "n" then break end

end



local ofile = io.open(saveName,"w")

ofile:write("return {\n\n")

for original,equivalent in pairs(dict) do
  ofile:write('["', original, '"] = {')
  for i,value in ipairs(equivalent) do
    ofile:write('{"',value[1],'",',tostring(value[2]),",",tostring(value[3]),",",tostring(value[4]),",",tostring(value[5]),"},")
  end
  ofile:write("},\n")
end

ofile:write("\n}\n")

