Given /^a newly created Git project$/ do
  @wcdir = Tmpdir.where(:wc)
  @wcdir.mkpath
  Dir.chdir(@wcdir) do
    git :init
    touch :README
    git :add, "."
    git :commit, "--message", "first commit"
  end
end

Given /^a newly created Subversion project$/ do
  @reposdir = Tmpdir.where(:repos)
  @reposdir.mkpath
  svnadmin :create, @reposdir 
  @wcdir = Tmpdir.where(:wc)
  svn :checkout, "file:///#{@reposdir}", @wcdir
end

Given /^a remote Git project named (\w+)$/ do |name|
  @remotewcdir = @remotereposdir = Tmpdir.where("remote/#{name}.git")
  @remotereposdir.mkpath
  Dir.chdir(@remotereposdir) do
    git :init
    touch :README
    git :add, "."
    git :commit, "--message", "initial commit"
  end
end

Given /^a remote Subversion project named (\w+)( using the classic layout)?$/ do |name, classic|
  @remotereposdir = Tmpdir.where("remote/repos/#{name}")
  @remotereposdir.mkpath
  svnadmin :create, @remotereposdir
  @remotewcdir = Tmpdir.where("remote/wc/#{name}")
  svn :checkout, "file:///#{@remotereposdir}", @remotewcdir
  if classic then
    svn :mkdir, @remotewcdir + "trunk", @remotewcdir + "branches", @remotewcdir + "tags"
    svn :commit, "--message", "classic layout", @remotewcdir
    @remotewcdir    = @remotewcdir + "trunk"
    @remotereposdir = @remotereposdir + "trunk"
  end
end
 
Given /^a file named ([^\s]+) with content "([^"]+)" in remote (\w+) project$/ do |filename, content, project|
  content.gsub!("\\n", "\n")
  File.open(@remotewcdir + filename, "w+") {|io| io.puts(content)}
  Dir.chdir(@remotewcdir) do
    if (@remotewcdir + ".git").directory? then
      git :add, "."
      git :commit, "--message", "adding #{filename}"
    else
      svn :add, filename
      svn :commit, "--message", "adding #{filename}"
    end
  end
end

Given /^an existing ([\w\/]+) folder$/ do |name|
  svn :mkdir, @wcdir + name
  svn :commit, "--message", "creating #{name}", @wcdir
end

When /^I import(?:ed)? ([\w\/]+)(?: into ([\w\/]+))?$/ do |project, into|
  Dir.chdir(@wcdir) do
    cmd = "#{Tmpdir.piston} import --verbose 5 file://#{@remotereposdir} 2>&1"
    cmd << " #{into}" if into
    STDERR.puts cmd.inspect if $DEBUG
    @stdout = `#{cmd}`
    STDERR.puts @stdout if $DEBUG
  end
end

When /^I update(?:ed)? ([\w\/]+)$/ do |path|
  Dir.chdir(@wcdir) do
    cmd = "#{Tmpdir.piston} update --verbose 5 #{@wcdir + path}  2>&1"
    STDERR.puts cmd.inspect if $DEBUG
    @stdout = `#{cmd}`
    STDERR.puts @stdout if $DEBUG
  end
end

When /^I committed$/ do
  if (@wcdir + ".git").directory?
    Dir.chdir(@wcdir) do
      git(:commit, "--message", "commit", "--all")
      stdout.should =~ /Created commit [a-fA-F0-9]+/
    end
  else
    stdout = svn(:commit, "--message", "commit", @wcdir)
    stdout.should =~ /Committed revision \d+/
  end
end

Then /^I should see "([^"]+)"(\s+debug)?$/ do |regexp, debug|
  re = Regexp.new(regexp, Regexp::IGNORECASE + Regexp::MULTILINE)
  STDERR.puts @stdout if debug
  @stdout.should =~ re
end

Then /^I should( not)? find a ([\w+\/]+) folder$/ do |not_find, name|
  if not_find then
    File.exist?(@wcdir + name).should_not be_true
    File.directory?(@wcdir + name).should_not be_true
  else
    File.exist?(@wcdir + name).should be_true
    File.directory?(@wcdir + name).should be_true
  end
end

Then /^I should find a ([.\w+\/]+) file$/ do |name|
  File.exist?(@wcdir + name).should be_true
  File.file?(@wcdir + name).should be_true
end
