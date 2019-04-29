#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'
require_relative 'tools'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: create-package [options]"
  opts.on("-r", "--repository REPOSITORY-PATH", "Repository path") { |v| options[:repository] = v }
  opts.on("-t", "--tag REPOSITORY-TAG", "Repository tag") { |v| options[:tag] = v }
end.parse!

abort "Missing repositry, use -r for repository path specify" unless options[:repository]
abort "Missing repositry tag, use -t for repository tag specify" unless options[:tag]

git_repo = open_git_repo(options[:repository])
addon_xml_content = get_file_content_from_git(git_repo, options[:tag], "addon.xml")
addon_detail = get_addon_info_from_xml(addon_xml_content)
git_archive(git_repo, options[:tag], addon_detail[:package_file])

puts addon_detail[:package_file]
