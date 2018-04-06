web: bash -c 'rerun -- bundle exec puma config.ru -p 3000'
push_worker: bash -c 'rerun -- bundle exec rake workers:start'
cleaner: bash -c 'rerun -- bundle exec rake database_cleaner:start'
#monitoring: bash -c 'rerun -- bundle exec rake monitoring:start'
