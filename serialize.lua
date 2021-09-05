local indent_level = 0

local indent = function()
  for i = 1, indent_level do
    io.write("  ")
  end
end

local serialize

serialize = function(item, level)

  if level then indent_level = level end

  if type(item) == "table" then
    io.write("{\n")
    indent_level = indent_level + 1
    for k,v in pairs(item) do
      indent() io.write("[") serialize(k) io.write("] = ") serialize(v) io.write(",\n")
    end
    indent_level = indent_level - 1
    indent(l) io.write("}")
  else
    io.write(string.format("%q", item))
  end

end

return serialize

