require 'optparse'
require 'ostruct'
require 'pp'

class SubtitleParser
	attr_accessor :input, :output, :op, :time

	def initialize (args)
		options = SubtitleParser.parse(args)
		if args.length != 2
			raise ArgumentError, "Error, must have a valid input and output file"
		end
		@op = options.operation
		@time = options.time
		@input = args[0]
		@output = args[1]
	end
	
	def self.parse(args)

		if args.empty?
			args << "-h"
		end
		
		options = OpenStruct.new
		options.operation = ""
		options.time = ""
	
		opts = OptionParser.new do |opts|
			opts.banner = "Usage: subtitleParse [options] input output"
		
			opts.on("-o add|sub", "--operation add|sub", "shifts subtitles forward or backward by --time amount") do |op|
				if (op.empty?)
					puts("Please enter an operation add or sub")
				elsif ((op == "add") || (op == "sub"))
					options.operation = op
				else
				end
			end

			opts.on("-t ss,mmm", "--time ss,mmm",  "Shift subtitles by time seconds,milliseconds before execution.") do |time|
				options.time = time
			end
		
			opts.on_tail("-h", "--help") do 
				puts opts
				exit
			end
		end
	
		opts.parse!(args)
		if (options.operation == "") 
			raise ArgumentError, "Error, need to put a valid operation flag", caller
		end
		if not(options.time.match(/\d\d,\d\d\d/))
			raise ArgumentError, "Error, need to put a valid time flag in the form dd,ddd", caller
		end
	options
	end
end

class SubTime
	attr_accessor :hour, :min, :sec, :ms
	def initialize(s)
		if s.length == 6
			@hour = 00
			@min = 00
			@sec = s[0..1].to_i
			@ms = s[3..5].to_i
		else
		@hour = s[0..1].to_i
		@min = s[3..4].to_i
		@sec = s[6..7].to_i
		@ms = s[9..11].to_i
		end
	end
	
	def add!(offset)
		self.hour += offset.hour
		self.min += offset.min
		self.sec += offset.sec
		self.ms += offset.ms
		self.normalize!
	end
	
	def sub!(offset)
		self.hour -= offset.hour
		self.min -= offset.min
		self.sec -= offset.sec
		self.ms -= offset.ms
		self.normalize!
	end
	
	def normalize!
		if self.ms >= 1000
			self.ms -= 1000
			self.sec += 1
		end
		if self.sec >= 60
			self.sec -= 60
			self.min += 1
		end
		if self.min >= 60
			self.min -= 60
			self.hour += 1
		end
		
		#normalize after subtracting
		if self.ms < 0 
			self.ms += 1000
			self.sec -= 1
		end
		if self.sec < 0
			self.sec += 60
			self.min -= 1
		end
		if self.min < 0
			self.min += 60
			self.hour -= 1
		end
		if self.hour < 0
			fail("Error, negative time.")
		end
	end
	
	def	to_s
	twoFormat = "%02d"
	threeFormat = "%03d"
	s = twoFormat % self.hour.to_s + ":" + twoFormat % self.min.to_s + ":" + twoFormat % self.sec.to_s + "," + threeFormat % self.ms.to_s
	s
	end
end


class SubtitleDelay
	parser = SubtitleParser.new(ARGV)
	time = SubTime.new(parser.time.to_s)
	timeregexp = /(?<before>\d\d:\d\d:\d\d,\d\d\d) --> (?<after>\d\d:\d\d:\d\d,\d\d\d)/
	if (parser.op == "add")
		#do addition
		newFile = File.new(parser.output.to_s, "w")
		File.open(parser.input) do |infile|
			while(line = infile.gets)
				if (r = line.match(timeregexp))
					newBefore = SubTime.new(r[:before])
					newBefore.add!(time)
					newAfter = SubTime.new(r[:after])
					newAfter.add!(time)
					
					line = newBefore.to_s + " --> " + newAfter.to_s + "\n"
				end
				newFile.write(line.to_s)
				puts line
			end
		end
	else 	#=> Do Subtraction
		newFile = File.new(parser.output.to_s, "w")
		File.open(parser.input) do |infile|
			while(line = infile.gets)
				if (r = line.match(timeregexp))
					newBefore = SubTime.new(r[:before])
					newBefore.sub!(time)
					newAfter = SubTime.new(r[:after])
					newAfter.sub!(time)
					line = newBefore.to_s + " --> " + newAfter.to_s + "\n"
				end	
				newFile.write(line.to_s)
				puts line
			end
		end
	end
end

