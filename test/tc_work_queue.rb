##
# = Name
# TC_WorkQueue
#
# == Description
# This file contains unit tests for the WorkQueue class.
#
# == Author
# Miguel Fonseca <fmmfonseca@gmail.com>
#
# == Copyright
# Copyright 2009-2010 Miguel Fonseca
#
# == License
# MIT (see LICENSE file)

require 'test/unit'
require 'lib/work_queue'

class TC_WorkQueue < Test::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_enqueue
    s = String.new
    wq = WorkQueue.new
    # using proc
    wq.enqueue_p(Proc.new { |str| str.replace("Hello #1") }, s)
    wq.join
    assert_equal(s, "Hello #1")
    # using block
    wq.enqueue_b(s) { |str| str.replace("Hello #2") }
    wq.join
    assert_equal(s, "Hello #2")
  end
  
  def test_inner_enqueue
    s = String.new
    wq = WorkQueue.new
    wq.enqueue_b do
      sleep 0.01
      wq.enqueue_b(s) { |str| str.replace("Hello #1")  }
      sleep 0.01
    end
    wq.join
    assert_equal(s, "Hello #1")
  end
  
  def test_threads_recycle
    wq = WorkQueue.new
    wq.enqueue_b { sleep 0.01 }
    sleep 0.02
    assert_equal(wq.cur_threads, 1)
    wq.enqueue_b { sleep 0.01 }
    assert_equal(wq.cur_threads, 1)
    wq.join
  end

  def test_max_threads
    assert_raise(ArgumentError) { WorkQueue.new(0) }
    assert_raise(ArgumentError) { WorkQueue.new(-1) }
    wq = WorkQueue.new(1)
    assert_equal(wq.cur_threads, 0)
    wq.enqueue_b { sleep(0.01) }
    assert_equal(wq.cur_threads, 1)
    wq.enqueue_b { sleep(0.01) }
    assert_equal(wq.cur_threads, 1)
    sleep(0.1)
    assert_equal(wq.cur_threads, 1)
    wq.join
  end

  def test_max_tasks
    assert_raise(ArgumentError) { WorkQueue.new(nil,0) }
    assert_raise(ArgumentError) { WorkQueue.new(nil,-1) }
    wq = WorkQueue.new(1,1)
    wq.enqueue_b { sleep(0.01) }
    wq.enqueue_b { sleep(0.01) }
    assert_equal(wq.cur_tasks, 1)
    wq.enqueue_b { sleep(0.01) }
    assert_equal(wq.cur_tasks, 1)
    wq.join
  end

  def test_stress
    a = []
    m = Mutex.new
    wq = WorkQueue.new(100,200)
    (1..1000).each do
      wq.enqueue_b(a,m) { |str,mut|
        sleep(0.01)
        mut.synchronize { a.push nil }
      }
    end
    wq.join
    assert_equal(a.size, 1000)
  end

end
