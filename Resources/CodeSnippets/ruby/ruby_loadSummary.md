```ruby
require "json"

def load_folio(path)
  JSON.parse(File.read(path))
end

project = load_folio(ARGV[0])
puts project
```
