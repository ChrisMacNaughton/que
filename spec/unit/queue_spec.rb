require 'spec_helper'

describe Que::Job, '.queue' do
  it "should be able to queue a job" do
    DB[:que_jobs].count.should be 0
    result = Que::Job.queue
    DB[:que_jobs].count.should be 1

    result.should be_an_instance_of Que::Job
    result.attrs[:priority].should == '1'
    result.attrs[:args].should == []

    job = DB[:que_jobs].first
    job[:priority].should be 1
    job[:run_at].should be_within(3).of Time.now
    job[:job_class].should == "Que::Job"
    JSON.load(job[:args]).should == []
  end

  it "should be able to queue a job with arguments" do
    DB[:que_jobs].count.should be 0
    Que::Job.queue 1, 'two'
    DB[:que_jobs].count.should be 1

    job = DB[:que_jobs].first
    job[:priority].should be 1
    job[:run_at].should be_within(3).of Time.now
    job[:job_class].should == "Que::Job"
    JSON.load(job[:args]).should == [1, 'two']
  end

  it "should be able to queue a job with complex arguments" do
    DB[:que_jobs].count.should be 0
    Que::Job.queue 1, 'two', :string => "string",
                             :integer => 5,
                             :array => [1, "two", {:three => 3}],
                             :hash => {:one => 1, :two => 'two', :three => [3]}

    DB[:que_jobs].count.should be 1

    job = DB[:que_jobs].first
    job[:priority].should be 1
    job[:run_at].should be_within(3).of Time.now
    job[:job_class].should == "Que::Job"
    JSON.load(job[:args]).should == [
      1,
      'two',
      {
        'string' => 'string',
        'integer' => 5,
        'array' => [1, "two", {"three" => 3}],
        'hash' => {'one' => 1, 'two' => 'two', 'three' => [3]}
      }
    ]
  end

  it "should be able to queue a job with a specific time to run" do
    DB[:que_jobs].count.should be 0
    Que::Job.queue 1, :run_at => Time.now + 60
    DB[:que_jobs].count.should be 1

    job = DB[:que_jobs].first
    job[:priority].should be 1
    job[:run_at].should be_within(3).of Time.now + 60
    job[:job_class].should == "Que::Job"
    JSON.load(job[:args]).should == [1]
  end

  it "should be able to queue a job with a specific priority" do
    DB[:que_jobs].count.should be 0
    Que::Job.queue 1, :priority => 4
    DB[:que_jobs].count.should be 1

    job = DB[:que_jobs].first
    job[:priority].should be 4
    job[:run_at].should be_within(3).of Time.now
    job[:job_class].should == "Que::Job"
    JSON.load(job[:args]).should == [1]
  end

  it "should be able to queue a job with queueing options in addition to argument options" do
    DB[:que_jobs].count.should be 0
    Que::Job.queue 1, :string => "string", :run_at => Time.now + 60, :priority => 4
    DB[:que_jobs].count.should be 1

    job = DB[:que_jobs].first
    job[:priority].should be 4
    job[:run_at].should be_within(3).of Time.now + 60
    job[:job_class].should == "Que::Job"
    JSON.load(job[:args]).should == [1, {'string' => 'string'}]
  end

  it "should respect a default (but overridable) priority for the job class" do
    class DefaultPriorityJob < Que::Job
      @default_priority = 3
    end

    DB[:que_jobs].count.should be 0
    DefaultPriorityJob.queue 1
    DefaultPriorityJob.queue 1, :priority => 4
    DB[:que_jobs].count.should be 2

    first, second = DB[:que_jobs].order(:job_id).all

    first[:priority].should be 3
    first[:run_at].should be_within(3).of Time.now
    first[:job_class].should == "DefaultPriorityJob"
    JSON.load(first[:args]).should == [1]

    second[:priority].should be 4
    second[:run_at].should be_within(3).of Time.now
    second[:job_class].should == "DefaultPriorityJob"
    JSON.load(second[:args]).should == [1]
  end

  it "should respect a default (but overridable) run_at for the job class" do
    class DefaultRunAtJob < Que::Job
      @default_run_at = -> { Time.now + 60 }
    end

    DB[:que_jobs].count.should be 0
    DefaultRunAtJob.queue 1
    DefaultRunAtJob.queue 1, :run_at => Time.now + 30
    DB[:que_jobs].count.should be 2

    first, second = DB[:que_jobs].order(:job_id).all

    first[:priority].should be 1
    first[:run_at].should be_within(3).of Time.now + 60
    first[:job_class].should == "DefaultRunAtJob"
    JSON.load(first[:args]).should == [1]

    second[:priority].should be 1
    second[:run_at].should be_within(3).of Time.now + 30
    second[:job_class].should == "DefaultRunAtJob"
    JSON.load(second[:args]).should == [1]
  end
end
