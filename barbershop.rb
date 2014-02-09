require 'java'

java_import java.util.concurrent.Executors
java_import java.util.concurrent.Semaphore
java_import java.util.concurrent.ArrayBlockingQueue
java_import java.util.concurrent.TimeUnit
java_import java.util.concurrent.CountDownLatch
java_import java.lang.Runnable

module BarberShop

  class Customer
    include Runnable

    def initialize(id)
        @id = id
    end

    def run

        @mutex.acquire
        if @customers == 20
            @latch.countDown
            @mutex.release
            customer "shop full"
            return
        end
        @customers += 1
        @mutex.release

        @standingRoom.put 1
        customer "enter shop"

        @sofa.put 1
        customer "sit on Sofa"
        @standingRoom.take

        @chair.acquire
        customer "sit in Barber Chair"
        @sofa.take

        @customerSem.release
        @barberSem.acquire
        customer "get hair cut"
        @chair.release

        customer "pay"
        @cash.release
        @receipt.acquire

        @mutex.acquire
        @customers -= 1
        @mutex.release

        customer "exit shop"
        @latch.countDown
    end

    def customer(action)
        puts "Customer #{@id} #{action}"
    end
  end

  class Barber
    include Runnable

    def initialize(id)
        @id = id
    end

    def run
        loop do
            @customerSem.acquire
            @barberSem.release
            barber "cut hair"

            @cash.acquire
            barber "accept payment"
            @receipt.release
        end
    end

    def barber(action)
        puts "Barber #{@id} #{action}"
    end
  end
end

customer_count = 0
mutex = Semaphore.new 1
standingRoom = ArrayBlockingQueue.new 16, true
sofa = ArrayBlockingQueue.new 4, true
chair = Semaphore.new 3
barberSem = Semaphore.new 0
customerSem = Semaphore.new 0
cash = Semaphore.new 0
receipt = Semaphore.new 0

totalCustomers = 100
latch = CountDownLatch.new(totalCustomers + 1)
totalBarbers = 3
customerPool = Executors.newFixedThreadPool 20
barberPool = Executors.newFixedThreadPool 3

barbers = (1..totalBarbers).map{|i| BarberShop::Barber.new(i)}
customers = (1..totalCustomers).map{|i| BarberShop::Customer.new(i)}

# Barbers and Customers share instance variables
(barbers + customers).each do |runnable|
    runnable.instance_eval do
        @customers = customer_count
        @mutex = mutex
        @standingRoom = standingRoom
        @sofa = sofa
        @chair = chair
        @barberSem = barberSem
        @customerSem = customerSem
        @cash = cash
        @receipt = receipt
        @latch = latch
    end
end

barbers.each{|barber| barberPool.submit barber}
customers.each{|customer| customerPool.submit customer}

latch.countDown
latch.await 10, TimeUnit::SECONDS

barberPool.shutdownNow
customerPool.shutdownNow