require 'cocoapods/dependency/version'
require 'cocoapods'
require 'pathname'
require 'pp'

module Cocoapods
  #
  # Analyze the project using cocoapods
  #
  class DependencyAnalyzer
    def self.analyze(podfile_dir_path)
      analyze_with_podfile(
        podfile_dir_path,
        Pod::Podfile.from_file(podfile_dir_path + 'Podfile'),
        Pod::Lockfile.from_file(Pathname.new(podfile_dir_path + 'Podfile.lock'))
      )
    end

    def self.analyze_with_podfile(podfile_dir_path, podfile, lockfile = nil)
      Dir.chdir(podfile_dir_path) do
        analyzer = Pod::Installer::Analyzer.new(
          Pod::Sandbox.new(Dir.mktmpdir),
          podfile,
          lockfile
        )

        specifications = analyzer.analyze.specifications.map(&:root).uniq

        map = {}
        specifications.each do |s|
          map[s.name] = if s.default_subspecs.count > 0
                          subspecs_with_name(s, s.default_subspecs) + s.dependencies
                        else
                          s.subspecs + s.dependencies
                        end
          s.subspecs.each do |ss|
            map[ss.name] = ss.dependencies
          end
        end

        new_map = {}

        map.each do |k, v|
          if v.empty?
            new_map[k] = v
            next
          end
          new_map[k] = find_dependencies(k, map, []).uniq
        end

        return new_map

        specifications.each do |s|
          puts "#{s.name} (#{s.version})"
          de = podfile.dependencies.find { |d| d.name.include?(s.name) }
          p de.name if de

          s.dependencies.each { |d| puts "  - #{d.name}" }
        end
      end
    end

    def self.find_dependencies(name, map, res)
      return unless map[name]
      res.push name if map[name].empty?
      map[name].each do |k|
        find_dependencies(k.name, map, res)
        res.push k.name
      end
      res
    end

    def self.subspecs_with_name(s, subspecs_short_names)
      ret = []
      subspecs_short_names.each do |name|
        ret.push(s.subspecs.find { |ss| ss.name.include? name })
      end
      ret
    end
  end
end
