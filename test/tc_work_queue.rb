##
# = Name
# TC_WorkQueue
#
# == Description
# This file contains unit tests for the WorkQueue class.
#
# == Author
# Miguel Fonseca <contact@miguelfonseca.com>
#
# == Copyright
# Copyright 2012 Miguel Fonseca
#
# == License
# MIT (see LICENSE file)

require 'test/unit'
require 'lib/work_queue'

class TC_WorkQueue < Test::Unit::TestCase
  def test_enqueue_proc
    s = String.new
    wq = WorkQueue.new
    wq.enqueue_p(Proc.new { |str| str.replace "Hello Proc" }, s)
    wq.join
    assert_equal "Hello Proc", s
  end
  
  def test_enqueue_block
    s = String.new
    wq = WorkQueue.new
    wq.enqueue_b(s) { |str| str.replace "Hello Block" }
    wq.join
    assert_equal "Hello Block", s
  end
  
  def test_inner_enqueue
    s = String.new
    wq = WorkQueue.new
    wq.enqueue_b do
      sleep 0.01
      wq.enqueue_b(s) { |str| str.replace "Hello Inner" }
      sleep 0.01
    end
    wq.join
    assert_equal "Hello Inner", s 
  end
  
  def test_threads_recycle
    wq = WorkQueue.new
    wq.enqueue_b { sleep 0.01 }
    sleep 0.02
    assert_equal 1, wq.cur_threads
    wq.enqueue_b { sleep 0.01 }
    assert_equal 1, wq.cur_threads
    wq.join
  end

  def test_max_threads
    wq = WorkQueue.new 1
    assert_equal 0, wq.cur_threads
    wq.enqueue_b { sleep 0.01 }
    assert_equal 1, wq.cur_threads
    wq.enqueue_b { sleep 0.01 }
    assert_equal 1, wq.cur_threads
    sleep 0.1
    assert_equal 1, wq.cur_threads
    wq.join
  end
  
  def test_max_threads_validation
    assert_raise(ArgumentError) { WorkQueue.new 0, nil }
    assert_raise(ArgumentError) { WorkQueue.new -1, nil }
  end

  def test_max_tasks
    wq = WorkQueue.new 1, 1
    wq.enqueue_b { sleep 0.01 }
    wq.enqueue_b { sleep 0.01 }
    assert_equal 1, wq.cur_tasks
    wq.enqueue_b { sleep 0.01 }
    assert_equal 1, wq.cur_tasks
    wq.join
  end
  
  def test_max_tasks_validation
    assert_raise(ArgumentError) { WorkQueue.new nil, 0 }
    assert_raise(ArgumentError) { WorkQueue.new nil, -1 }
  end

  def test_stress
    i = 0
    m = Mutex.new
    wq = WorkQueue.new 100, 200
    (1..10000).each do
      wq.enqueue_b {
        sleep 0.01
        m.synchronize { i += 1 }
      }
    end
    wq.join
    assert_equal 10000, i
  end
  
  def test_stress_prolonged
    i = 0
    m = Mutex.new
    wq = WorkQueue.new 100, 200
    (1..10000).each do
      wq.enqueue_b {
        sleep rand(5)
        m.synchronize { i += 1 }
      }
    end
    wq.join
    assert_equal 10000, i
  end

  def test_kill
    s = String.new
    wq = WorkQueue.new
    wq.enqueue_b(s) { |str| 
      sleep 0.1
      str.replace "Hello"
    }
    wq.kill
    assert(s.empty?)
  end
end
