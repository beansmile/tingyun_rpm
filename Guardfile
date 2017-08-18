# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
# directories %w(app lib config test spec features) \
#  .select{|d| Dir.exists?(d) ? d : UI.warning("Directory #{d} does not exist")}

## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"

guard :minitest, :test_folders => ['test/ting_yun'], :all_after_pass => false do
  # with Minitest::Unit
  watch(%r{^lib/(.+)\.rb$})     { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/.+_test\.rb$})
  watch('test/test_helper.rb')  { "test/tingyun" }
  watch('test/agent_helper.rb') { "test/tingyun" }

end

guard "rubycritic" do
  watch(%r{^app/(.+)\.rb$})
  watch(%r{^lib/(.+)\.rb$})
end

# A sample Guardfile
# More info at https://github.com/guard/guard#readme


