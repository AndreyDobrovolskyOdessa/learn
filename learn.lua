#!/usr/bin/env lua


local Serialize = dofile("serialize.lua")


local dict = {
  lang = {},
  data = {},
}

local saved_name = "learn.save"



local AppendDict = function(new_dict)

  if new_dict.lang then
    for i,new_lang in ipairs(new_dict.lang) do
      if not dict.lang[new_lang] then
        table.insert(dict.lang,new_lang)
        dict.lang[new_lang] = #dict.lang
      end
    end
  end

  if new_dict.data then
    for i,new_data in ipairs(new_dict.data) do
      local reordered_data = {}
      for j,k in ipairs(new_data) do
        reordered_data [dict.lang[new_dict.lang[j]]] = type(k) == "table" and k or {k}
      end
      table.insert(dict.data, reordered_data)
    end
  end

  if new_dict.pairs then
    if not dict.query then dict.query = {} end
    for i,j in ipairs(new_dict.pairs) do
      local langQ = dict.lang[j[1]]
      local langA = dict.lang[j[2]]
      if not dict.query[langQ] then dict.query[langQ] = {} end
      if not dict.query[langQ][langA] then dict.query[langQ][langA] = {} end
    end
  end
end


local CollectVocabularies = function()
  dict.vocabulary = {}
  for i = 1,#dict.lang do
    dict.vocabulary[i] = {}
  end
  for i,record in ipairs(dict.data) do
    for lang,words in pairs(record) do
      local vocabulary = dict.vocabulary[lang]
      for j,word in ipairs(words) do
        if not vocabulary[word] then
          table.insert(vocabulary,word)
          vocabulary[word] = {}
        end
        table.insert(vocabulary[word],i)
      end
    end
  end
end


local TraverseQueryWith = function(f)
  for langQ=1,#dict.lang do
    if dict.query[langQ] then
      for langA=1,#dict.lang do
        if dict.query[langQ][langA] then
          for i,wordQ in ipairs(dict.vocabulary[langQ]) do
            local result = f(langQ, langA, i, wordQ)
            if result ~= nil then return result end
          end
        end
      end
    end
  end
end


local initial_freq = 4


local FillQuery = function()
  dict.freq_total = 0

  TraverseQueryWith(
    function(langQ, langA, i, wordQ)
      dict.query[langQ][langA][i] = {}
      local answer = dict.query[langQ][langA][i]
      answer[0] = {initial_freq, 0}
      for j,data_line in ipairs(dict.vocabulary[langQ][wordQ]) do
        if dict.data[data_line][langA] then
          for k,wordA in ipairs(dict.data[data_line][langA]) do
            if not answer[wordA] then
              table.insert(answer, wordA)
              answer[wordA] = {initial_freq, 0}
            end
          end
        end
      end
      dict.freq_total = dict.freq_total + initial_freq
    end
  )
end 


local AnswerFor = function(q)
  return dict.query[q[1]][q[2]][q[3]]
end


local RestoreFreq = function()
  if dict.question then
    local correct = AnswerFor(dict.question)
    dict.freq_total = dict.freq_total - correct[0][1]
    for i,word in ipairs(correct) do
      if correct[0][1] < correct[word][1] then
        correct[0][1] = correct[word][1]
      end
    end
    dict.freq_total = dict.freq_total + correct[0][1]
  else
    dict.question = {}
  end
end


local SelectWordQ = function()

  if dict.freq_total == 0 then
   io.write("\nDone!\n\n")
    return false
  end

  io.write("\n\nNext question? [ Yn ] : ")
  if io.read() ~= "" then return false end

  os.execute("clear")

  local dice = math.random(dict.freq_total)
  local freq = 0

  return TraverseQueryWith(
    function(langQ, langA, i, wordQ)
      local cur = {langQ, langA, i}
      local answer = AnswerFor(cur)
      freq = freq + answer[0][1]
      if freq >= dice then
        RestoreFreq()
        dict.freq_total = dict.freq_total - answer[0][1]
        answer[0][1] = 0
        answer[0][2] = answer[0][2] + 1
        dict.question = cur
        return true
      end  
    end
  )
end


local ShowQuestion = function()
  io.write(dict.lang[dict.question[1]], " : ")
  io.write(dict.vocabulary[dict.question[1]][dict.question[3]], "\n\n")
end


local InputAnswer = function()
  local correct = AnswerFor(dict.question)
  local answer = {}
  for i=1,#correct do
    io.write(dict.lang[dict.question[2]], " : ")
    local next_answer = io.read()
    if next_answer == "" then break end
    table.insert(answer,next_answer)
  end
  return answer
end


local CheckAnswer = function(answer)
  local correct = AnswerFor(dict.question)
  local present = {}
  local success = true

  local indent = string.rep(" ",utf8.len(dict.lang[dict.question[2]]) + 3)

  for i,word in ipairs(answer) do
    if correct[word] then
      present[word] = true
    else
      present[word] = false
      success = false
    end
  end

  if success then
    for word,i in pairs(present) do
      correct[word][1] = correct[word][1] // 2
      correct[word][2] = correct[word][2] + 1
    end
  else
    for i,word in ipairs(correct) do
      correct[word][1] = dict.freq_total
      correct[word][2] = 0
    end
    io.write("\n\nErrors :\n\n")
    for word,i in pairs(present) do
      if not correct[word] then
        io.write(indent, word, "\n")
      end
    end
  end

  io.write("\n\nAnswer :\n\n")
  for i,word in ipairs(correct) do
    io.write(indent,string.format("%-40s",word),correct[word][1],"\n")
  end
end


local ShowStats = function()

  local questions_total = 0
  local hist = {}

  TraverseQueryWith(
    function(langQ, langA, i, wordQ)
      local cur = {langQ, langA, i}
      local answer = AnswerFor(cur)
      questions_total = questions_total + answer[0][2]
      for j,wordA in ipairs(answer) do
        local k = answer[wordA][2]
        hist[k] = hist[k] and hist[k] + 1 or 1
      end
    end
  )

  io.write("\nQuestions total = ", questions_total, "\n\n")

  for i=0,9 do
    io.write(i," ",string.rep("#",hist[i] or 0),"\n")
  end

  io.write("\n")

end


io.write("Learn 0.1 Copyright (C) 2021 Andrey Dobrovolsky\n")


if #arg == 0 then
  dict = dofile(saved_name)
else

  for i,name in ipairs(arg) do
    AppendDict(dofile(name))
  end

  if dict.query then
    CollectVocabularies()
    FillQuery()
  end

end



if dict.query then

  math.randomseed(os.time())

  while SelectWordQ() do
    ShowQuestion()
    CheckAnswer(InputAnswer())
  end

  ShowStats()
end


io.output(saved_name) io.write("return ") Serialize(dict) io.write("\n")

os.exit()



