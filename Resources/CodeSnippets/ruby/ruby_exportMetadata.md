```ruby
require "json"

FIELDS = %w[
  id filePath title subtitle summary description domain category status
  phase isPublic featured requiresFollowUp tags mediums genres topics
  subjects customFlag customNumber customObject
]

def export_metadata(path, out = nil)
  raw = JSON.parse(File.read(path))
  meta = raw.slice(*FIELDS)
  out ||= path.sub(/\.folio.*/, ".metadata.json")
  File.write(out, JSON.pretty_generate(meta))
end
```
