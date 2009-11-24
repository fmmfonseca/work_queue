##
# = Name
# WorkQueue
#
# == Description
# This file contains an implementation of a work queue structure.
#
# == Version
# 0.1.1
#
# == Author
# Miguel Fonseca <fmmfonseca@gmail.com>
#
# == Copyright
# Copyright 2009 Miguel Fonseca
#
# == License
# MIT (see LICENSE file)
#

require 'thread'
require 'timeout'

##
# = WorkQueue
#
# == Description
# A tunable work queue, designed to coordinate work between a producer and a pool of worker threads.
#
# == Usage
#  wq = WorkQueue.new
#  wq.enqueue_b { puts "Hello from the WorkQueue" }
#  wq.join
#
class WorkQueue
	
	VERSION = "0.1.1"
	
	##
	# Creates a new work queue with the desired parameters.
	#	
	#  wq = WorkQueue.new(5,10,20)
	#
	def initialize(max_threads=nil, max_tasks=nil, keep_alive=60)
		self.max_threads = max_threads
		self.max_tasks = max_tasks
		self.keep_alive = keep_alive
		@threads = []
		@threads_lock = Mutex.new
		@tasks = max_tasks ? SizedQueue.new(max_tasks) : Queue.new
		@threads.taint
		@tasks.taint
		self.taint
	end
	
	##
	# Returns the maximum number of worker threads.
	# This value is set upon initialization and cannot be changed afterwards.
	#
	#  wq = WorkQueue.new()
	#  wq.max_threads		#=> Infinity
	#  wq = WorkQueue.new(1)
	#  wq.max_threads		#=> 1
	#
	def max_threads
		@max_threads
	end
	
	##
	# Returns the current number of worker threads.
	# This value is just a snapshot, and may change immediately upon returning.
	#
	#  wq = WorkQueue.new(10)
	#  wq.cur_threads		#=> 0
	#  wq.enqueue_b {}
	#  wq.cur_threads		#=> 1
	#
	def cur_threads
		@threads.size
	end
	
	##
	# Returns the maximum number of queued tasks.
	# This value is set upon initialization and cannot be changed afterwards.
	#
	#  wq = WorkQueue.new()
	#  wq.max_tasks		#=> Infinity
	#  wq = WorkQueue.new(nil,1)
	#  wq.max_tasks		#=> 1
	#
	def max_tasks
		@max_tasks
	end
	
	##
	# Returns the current number of queued tasks.
	# This value is just a snapshot, and may change immediately upon returning.
	#
	#  wq = WorkQueue.new(1)
	#  wq.enqueue_b { sleep(1) }
	#  wq.cur_tasks		#=> 0
	#  wq.enqueue_b {}
	#  wq.cur_tasks		#=> 1
	#
	def cur_tasks
		@tasks.size
	end
	
	##
	# Returns the number of seconds to keep worker threads alive waiting for new tasks.
	# This value is set upon initialization and cannot be changed afterwards.
	#
	#  wq = WorkQueue.new()
	#  wq.keep_alive		#=> 60
	#  wq = WorkQueue.new(nil,nil,1)
	#  wq.keep_alive		#=> 1
	#
	def keep_alive
		@keep_alive
	end
	
	##
	# Schedules the given Proc for future execution by a worker thread.
	# If there is no space left in the queue, waits until space becomes available.
	#
	#  wq = WorkQueue.new(1)
	#  wq.enqueue_p(Proc.new {})
	#
	def enqueue_p(proc, *args)
		@tasks << [proc,args]
		spawn_thread
		self
	end
	
	##
	# Schedules the given Block for future execution by a worker thread.
	# If there is no space left in the queue, waits until space becomes available.
	#
	#  wq = WorkQueue.new(1)
	#  wq.enqueue_b {}
	#
	def enqueue_b(*args, &block)
		@tasks << [block,args]
		spawn_thread
		self
	end
	
	##
	# Waits until the tasks queue is empty and all worker threads have finished.
	#
	#  wq = WorkQueue.new(1)
	#  wq.enqueue_b { sleep(1) }
	#  wq.join
	#
	def join
		cur_threads.times { dismiss_thread }
		@threads.dup.each { |t| t.join }
		self
	end
	
	##
	# Stops all worker threads immediately, aborting any ongoing tasks.
	#
	#  wq = WorkQueue.new(1)
	#  wq.enqueue_b { sleep(1) }
	#  wq.stop
	#
	def stop
		@threads.dup.each { |t| t.exit.join }
		@tasks.clear
		self
	end
	
	private
	
	##
	# Sets the maximum number of worker threads.
	#
	def max_threads=(value)
		raise ArgumentError, "the maximum number of threads must be positive" if value and value <= 0
		@max_threads = value || 1.0/0
	end
	
	##
	# Sets the maximum number of queued tasks.
	#
	def max_tasks=(value)
		raise ArgumentError, "the maximum number of tasks must be positive" if value and value <= 0
		@max_tasks = value || 1.0/0
	end
	
	##
	# Sets the maximum time to keep worker threads alive waiting for new tasks.
	#
	def keep_alive=(value)
		raise ArgumentError, "the keep-alive time must be positive" if value and value <= 0
		@keep_alive = value || 1.0/0
	end
	
	##
	# Enrolls a new worker thread.
	# The request is only carried out if necessary.
	#
	def spawn_thread
		if cur_threads < max_threads and @tasks.num_waiting <= 0 and cur_tasks > 0
			@threads_lock.synchronize { 
				@threads << Thread.new do
					begin
						work()
					ensure
						@threads_lock.synchronize { @threads.delete(Thread.current) }
					end
				end
			}
		end
	end
	
	##
	# Instructs an idle worker thread to exit.
	# The request is only carried out if necessary.
	#
	def dismiss_thread
		@tasks << [Proc.new { Thread.exit }, nil] if cur_threads > 0
	end
	
	##
	# Repeatedly process the tasks queue.
	#
	def work
		loop do
			begin
				proc, args = timeout(keep_alive) { @tasks.pop }
				proc.call(*args)
			rescue Timeout::Error
				break
			rescue Exception
				# suppress exception
			end
			break if cur_threads > max_threads
		end
	end
	
end