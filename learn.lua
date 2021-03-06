#!/usr/bin/env lua


local Serialize = dofile("serialize.lua")


local dict = {
  lang = {},
  data = {},
}

-------------------------------------------
-- Constants ------------------------------
-------------------------------------------

local success_max
local freq_decrement_base

-------------------------------------------

local freq_init

-------------------------------------------

local LoadConstants = function()
  success_max = dict.success_max or 3
  freq_decrement_base = dict.freq_decrement_base or 2

  freq_init = math.ceil(math.ceil(freq_decrement_base) ^ success_max)
end


local query_mt = {
  __index = function(t,k)
              t[k] = {[0] = {0, 0}}
              return t[k]
            end
}


local Trim = function(l)
  l = string.match(l, "%s*(.-)%s*$")
  l = string.gsub (l, "(%p)", "%1 ")
  l = string.gsub (l, "%s+", " ")
  l = string.gsub (l, " (%p)", "%1")

  return l
end


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
      for j,x in ipairs(new_data) do
        local new_table = type(x) == "table" and x or {x}
        for k,v in ipairs(new_table) do
          new_table[k] = Trim(v)
        end
        reordered_data [dict.lang[new_dict.lang[j]]] = new_table
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
      if not dict.query[langQ][langA] then dict.query[langQ][langA] = setmetatable({}, query_mt) end
    end
  end

  if new_dict.success_max then
    dict.success_max = math.min(math.max(math.floor(new_dict.success_max), 1), 9)
  end

  if new_dict.freq_decrement_base then
    dict.freq_decrement_base = math.min(math.max(new_dict.freq_decrement_base, 1), 10)
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


local AnswerFor = function(q)
  return q and dict.query[q[1]][q[2]][q[3]]
end


local TraverseQueryWith = function(f)
  for langQ=1,#dict.lang do
    if dict.query[langQ] then
      for langA=1,#dict.lang do
        if dict.query[langQ][langA] then
          for i,wordQ in ipairs(dict.vocabulary[langQ]) do
            local question = {langQ, langA, i}
            if f(question, AnswerFor(question), wordQ) then
              return
            end
          end
        end
      end
    end
  end
end


local MaxFreq = function(ans)
  local m = 0
  for i,word in ipairs(ans) do
    m = math.max(m, ans[word][1])
  end
  return m
end


local Refill = function(wt, wf_init)
  for i,word in ipairs(wt) do
    local w = wt[word]
    w[1] = wf_init
    w[2] = 0
  end
end


local ChangeFreq = function(t, v)
    dict.freq_total = dict.freq_total - t[1] + v
    t[1] = v
end


local RestoreFreq = function(answer)
  if answer then
    ChangeFreq(answer[0], MaxFreq(answer))
  end
end


local FillQuery = function()
  dict.freq_total = 0
  LoadConstants()

  TraverseQueryWith(
    function(question, answer, wordQ)
      for j,data_line in ipairs(dict.vocabulary[question[1]][wordQ]) do
        if dict.data[data_line][question[2]] then
          for k,wordA in ipairs(dict.data[data_line][question[2]]) do
            if not answer[wordA] then
              table.insert(answer, wordA)
              answer[wordA] = {}
            end
          end
        end
      end
      Refill(answer, freq_init)
      RestoreFreq(answer)
    end
  )
end 


local correct


local SelectQuestion = function()

  if dict.freq_total == 0 then
    RestoreFreq(correct)
  end

  if dict.freq_total == 0 then
    io.write("\nDone!\n\n")
    return false
  end

  io.write("\n\nPress <ENTER> to continue ( any symbols to interrupt ) : ")
  if io.read() ~= "" then
    return false
  end

  local dice = math.random(dict.freq_total)
  local freq = 0

  TraverseQueryWith(
    function(question, answer)
      freq = freq + answer[0][1]
      if freq >= dice then
        RestoreFreq(correct)

        dict.question = question
        correct = answer

        return true
      end  
    end
  )

  return true
end


local InputAnswer = function()
  os.execute("clear")

  io.write(dict.lang[dict.question[1]], " : ")
  io.write(dict.vocabulary[dict.question[1]][dict.question[3]], "\n\n")

  local answer = {}
  for i=1,#correct do
    io.write(dict.lang[dict.question[2]], " : ")
    local next_answer = io.read()
    if next_answer == "" then
      break
    end
    table.insert(answer,Trim(next_answer))
  end

  return answer
end


local Reward = function(w)
  if w[2] < success_max then
    w[1] = math.floor(w[1] / freq_decrement_base)
    w[2] = w[2] + 1
  end
  if w[2] >= success_max then
    w[1] = 0
  end
end


local CheckAnswer = function(answer)

  ChangeFreq(correct[0], 0)
  correct[0][2] = correct[0][2] + 1

  local good = {}
  local bad = {}

  for i,word in ipairs(answer) do
    table.insert(correct[word] and good or bad, word)
  end

  for i,word in ipairs(good) do
    Reward(correct[word])
  end

  local indent = string.rep(" ",utf8.len(dict.lang[dict.question[2]]) + 3)

  if #bad > 0 or #good == 0 then
    Refill(correct, math.max(dict.freq_total, freq_init))
    io.write("\n\nError!\n\n")
    for i,word in ipairs(bad) do
      io.write(indent, word, "\n")
    end
  end

  io.write("\n\nCorrect :\n\n")
  for i,word in ipairs(correct) do
    io.write(indent, word, " ")
    io.write(string.rep("+", correct[word][2]))
    io.write(string.rep("-", success_max - correct[word][2]), "\n")
  end
end


local ShowStats = function()

  local questions_total = 0
  local hist = {}

  TraverseQueryWith(
    function(question, answer)
      questions_total = questions_total + answer[0][2]
      for j,wordA in ipairs(answer) do
        local k = answer[wordA][2]
        hist[k] = hist[k] and hist[k] + 1 or 1
      end
    end
  )

  io.write("\nQuestions total = ", questions_total, "\n")

  for i=0,success_max do
    io.write("\n",i," ")
    if hist[i] then
      io.write(string.rep(">", math.floor(math.log(hist[i])/math.log(2))+1))
      io.write( hist[i] > 2 and hist[i] or "")
    end
  end

  io.write("\n\nMemory usage = ", math.ceil(collectgarbage("count")), " kB\n\n")

end


io.write("Learn 0.3 Copyright (C) 2021 Andrey Dobrovolsky\n")


local saved_name = "learn.save"


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
  LoadConstants()
  correct = AnswerFor(dict.question)

  math.randomseed(os.time())

  while SelectQuestion() do
    CheckAnswer(InputAnswer())
  end

  ShowStats()
end


io.output(saved_name) io.write("return ") Serialize(dict) io.write("\n")


