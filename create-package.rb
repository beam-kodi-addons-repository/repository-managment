#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'git'
require 'optparse'
require 'rexml/document'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: create-package [options]"
  opts.on("-r", "--repository REPOSITORY-PATH", "Repository path") { |v| options[:repository] = v }
  opts.on("-t", "--tag REPOSITORY-TAG", "Repository tag") { |v| options[:tag] = v }
  opts.on("-f", "--file", "Explicit archive file name") { |v| options[:file] = v }
  opts.on("-p", "--package", "Explicit package name") { |v| option[:package] = v }
  opts.on("-v", "--version", "Explicit package version") { |v| options[:version] = v }
end.parse!

unless options[:repository]
  puts "Missing repositry, use -r for repository path specify"
  exit 1
end

unless options[:tag]
  puts "Missing repositry tag, use -t for repository tag specify"
  exit 1
end


git_repo = Git.open(options[:repository])
xmldoc = REXML::Document.new(git_repo.show(options[:tag], "addon.xml"))
addon_name = options[:package] || xmldoc.elements["addon"].attribute(:id)
addon_version = options[:package] || xmldoc.elements["addon"].attribute(:version)
addon_export_file = options[:file] || "#{addon_name}-#{addon_version}.zip"
git_repo.archive(options[:tag], addon_export_file)

puts addon_export_file
