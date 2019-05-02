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
  opts.on("-f", "--filename FILENAME", "Save release filename into this file") { |v| options[:file_name] = v }
end.parse!

abort "Missing repositry, use -r for repository path specify" unless options[:repository]
abort "Missing repositry tag, use -t for repository tag specify" unless options[:tag]

export_file_name = options[:file_name] || "RELEASE_NAME"

$logger.info("Opening package git repositry")
git_repo = open_git_repo(options[:repository])
$logger.info("Reading addon.xml file from git")
addon_xml_content = get_file_content_from_git(git_repo, options[:tag], "addon.xml")
$logger.info("Parsing addon.xml details")
addon_detail = get_addon_info_from_xml(addon_xml_content)
$logger.info("Creating package #{addon_detail[:package_file]}")
git_archive(git_repo, options[:tag], addon_detail[:package_file], addon_detail[:addon_id])

$logger.info("Saving package filename into #{export_file_name}")
File.write(export_file_name, addon_detail[:package_file])
