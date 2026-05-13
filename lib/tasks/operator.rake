namespace :operator do
  desc "Print a fresh operator JWT signed with JWT_SECRET"
  task token: :environment do
    puts JsonWebToken.encode(role: "operator")
  end
end
