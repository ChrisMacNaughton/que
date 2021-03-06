## Writing Reliable Jobs

Que does everything it can to ensure that jobs are worked exactly once, but if something bad happens when a job is halfway completed, there's no way around it - the job will need be repeated over again from the beginning, probably by a different worker. When you're writing jobs, you need to be prepared for this to happen.

The safest type of job is one that reads in data, either from the database or from external APIs, then does some number crunching and writes the results to the database. These jobs are easy to make safe - simply write the results to the database inside a transaction, and also have the job destroy itself inside that transaction, like so:

    class UpdateWidgetPrice < Que::Job
      def run(widget_id)
        widget = Widget[widget_id]
        price  = ExternalService.get_widget_price(widget_id)

        ActiveRecord::Base.transaction do
          # Make changes to the database.
          widget.update :price => price

          # Destroy the job.
          destroy
        end
      end
    end

Here, you're taking advantage of the guarantees of an [ACID](https://en.wikipedia.org/wiki/ACID) database. The job is destroyed along with the other changes, so either the write will succeed and the job will be run only once, or it will fail and the database will be left untouched. But even if it fails, the job can simply be retried, and there are no lingering effects from the first attempt, so no big deal.

The more difficult type of job is one that makes changes that can't be controlled transactionally. For example, writing to an external service:

    class ChargeCreditCard < Que::Job
      def run(user_id, credit_card_id)
        CreditCardService.charge(credit_card_id, :amount => "$10.00")

        ActiveRecord::Base.transaction do
          User.where(:id => user_id).update_all :charged_at => Time.now
          destroy
        end
      end
    end

What if the process abruptly dies after we tell the provider to charge the credit card, but before we finish the transaction? Que will retry the job, but there's no way to tell where (or even if) it failed the first time. The credit card will be charged a second time, and then you've got an angry customer. The ideal solution in this case is to make the job [idempotent](https://en.wikipedia.org/wiki/Idempotence), meaning that it will have the same effect no matter how many times it is run:

    class ChargeCreditCard < Que::Job
      def run(user_id, credit_card_id)
        unless CreditCardService.check_for_previous_charge(credit_card_id)
          CreditCardService.charge(credit_card_id, :amount => "$10.00")
        end

        ActiveRecord::Base.transaction do
          User.where(:id => user_id).update_all :charged_at => Time.now
          destroy
        end
      end
    end

This makes the job slightly more complex, but reliable (or, at least, as reliable as your credit card service).

Finally, there are some jobs where you won't want to write to the database at all:

    class SendVerificationEmail < Que::Job
      def run(email_address)
        Mailer.verification_email(email_address).deliver
      end
    end

In this case, we don't have any no way to prevent the occasional double-sending of an email. But, for ease of use, you can leave out the transaction and the `destroy` call entirely - Que will recognize that the job wasn't destroyed and will clean it up for you.
