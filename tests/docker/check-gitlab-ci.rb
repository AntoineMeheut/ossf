# Simulated VM 1: run through gitlab-rails runner to use the installed GitLab validator.
# Validate the CI configuration without running jobs or publishing packages/images.
# Run with gitlab-rails runner in the disposable GitLab test instance.
root = ARGV.fetch(0)
# Include the nested .gitlab-ci.yml examples as well as the original Audit files.
files = Dir.glob(File.join(root, '**', '*.yml'), File::FNM_DOTMATCH).select { |path| File.file?(path) }
abort 'No CI examples found' if files.empty?
# Examine every example and fail overall if at least one file is invalid.
failed = false
files.each do |path|
  result = Gitlab::Ci::YamlProcessor.new(File.read(path)).execute
  if result.valid?
    puts "PASS: GitLab CI validation: #{path.delete_prefix(root + '/')}"
  else
    warn "FAIL: #{path.delete_prefix(root + '/')}: #{result.errors.join('; ')}"
    failed = true
  end
end
abort 'Invalid GitLab CI examples' if failed
