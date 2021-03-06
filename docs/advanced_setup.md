## Advanced Setup

If you're using both Rails and ActiveRecord, the README describes how to get started with Que (which is pretty straightforward, since Que includes a Railtie that handles a lot of setup for you). Otherwise, you'll need to do some manual setup.

If you're using ActiveRecord outside of Rails, you'll need to tell Que to piggyback on its connection pool after you've connected to the database:

    ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

    require 'que'
    Que.connection = ActiveRecord

Then you can queue jobs just as you would in Rails:

    ActiveRecord::Base.transaction do
      @user = User.create(params[:user])
      SendRegistrationEmail.queue :user_id => @user.id
    end

There are other docs to read if you're using [Sequel](https://github.com/chanks/que/blob/master/docs/using_sequel.md) or [plain Postgres connections](https://github.com/chanks/que/blob/master/docs/using_plain_connections.md) (with no ORM at all) instead of ActiveRecord.

### Managing the Jobs Table

After you've connected Que to the database, you can manage the jobs table:

    # Create the jobs table:
    Que.create!

    # Clear the jobs table of all jobs:
    Que.clear!

    # Drop the jobs table:
    Que.drop!

### Other Setup

You can give Que a logger to use if you like:

    Que.logger = Logger.new(STDOUT)

You'll also need to set Que's mode manually:

    # Start the worker pool:
    Que.mode = :async

    # Or, when testing:
    Que.mode = :sync

Be sure to read the docs on [managing workers](https://github.com/chanks/que/blob/master/docs/managing_workers.md) for more information on using the worker pool.

You may also want to set up an [error handler](https://github.com/chanks/que/blob/master/docs/error_handling.md) to track errors raised by jobs.
