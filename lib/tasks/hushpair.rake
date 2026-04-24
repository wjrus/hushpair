namespace :hushpair do
  desc "Expire inactive rooms, enforce message retention, and purge old closed rooms"
  task maintenance: :environment do
    RoomMaintenanceJob.perform_now
  end
end
