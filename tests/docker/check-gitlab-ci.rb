# Simulated VM 1: run through gitlab-rails runner to use the installed GitLab validator.
# Validate the CI configuration without running jobs or publishing packages/images.
# Run with gitlab-rails runner in the disposable GitLab test instance.
files = Dir.glob(File.join(ARGV.fetch(0), '*.yml'))
abort 'No CI examples found' if files.empty?
# Examine every example and fail overall if at least one file is invalid.
failed = false
files.each do |path|
  result = Gitlab::Ci::YamlProcessor.new(File.read(path)).execute
  if result.valid?
    puts "PASS: GitLab CI validation: #{File.basename(path)}"
  else
    warn "FAIL: #{File.basename(path)}: #{result.errors.join('; ')}"
    failed = true
  end
end
abort 'Invalid GitLab CI examples' if failed
