# Workshops

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/fe8b8c203df8443583d1e26080d1849d)](https://app.codacy.com/gh/birs-math/workshops?utm_source=github.com&utm_medium=referral&utm_content=birs-math/workshops&utm_campaign=Badge_Grade_Settings)

"Workshops" is software for managing scientific meetings, or small conferences. It was created by [Brent Kearney](https://github.com/brentkearney/workshops) with [Ruby on Rails](http://rubyonrails.org)
and released under the GPL-A open-source license. The software is intended to be used by institutions/organizations who host workshops. It is used at the
[Banff International Research Station](https://workshops.birs.ca/events/future) for managing workshops.


Contributions to the project are most welcome. Check out the [Project Page](https://github.com/birs-math/workshops.git/projects/1) for whats happening in development now. If you would like to add features yourself, please
[let me know](mailto:brentk@birs.ca), and/or submit a Pull Request. Or if you would like to pay for the development of additional features,
please [contact me](mailto:brent@netmojo.ca).

Installation instructions are below.

## Current Features
*  **Sign-ins and sign-ups** for staff and admin users, and invited workshop participants.

*  **Fine-grained, role-based access controls** allows different levels of access privileges for admin, staff, organizers, participants,
   and public. (Uses [Pundit](https://github.com/varvet/pundit).)

*  **Add Members** Staff and Organizers can add members to their workshops.

*  **Event Invitations & Reminders** Staff and Organizers can click a button to send invitation emails to potential participants. The emails contain a unique link, giving them access to the built-in RSVP system.

*  **RSVPs** allows invited participants to reply to their invitation with "Yes", "No", "Maybe". Includes a text area to send a personal
   note to the organizer. If confirming, collects data for hotel reservations, etc., via a web form (unique per location) that is optimized for autofill. Text descriptions of the form fields are user-editable via the Settings function. Automatically sends a confirmation email to confirmed participants, using email templates based on workshop type. Email notifications are also sent to staff and organizers.

*  **3rd Party Mail Service Integration** for improved email deliverability, use SparkPost, Mailgun, etc.. Uses direct SMTP for staff messages.

*  **Multiple locations** for events. Each location has its own settings, email templates, forms, etc..

*  **Workshop scheduling**: organizers can enter their workshop schedules, including talks with abstracts/descriptions, and choose when to publish their schedules to the public.

*  **Default schedule templates** Staff may edit a special "template" schedule that gets applied to all events who do not yet have a schedule. Certain schedule items can be "locked", so that organizers cannot change them without staff permission.

*  **JSON output** of schedules and other event data, for easy display on external websites,
   [like this](http://www.birs.ca/events/2017/5-day-workshops/17w5030/schedule). Uses JWT authentication for JSON access to privileged data.

*  **Authenticated JSON API** for [an external video recording system](http://www.birs.ca/facilities/automated-video) to update lecture records in the schedule, based on recordings made.

*  **LaTeX formatting** in all text editing areas, via [MathJax](https://www.mathjax.org), for mathematical formulae.

*  **Email notifications** for staff and organizers when data changes, such as participant RSVPs and schedule updates during currently running workshops.

*  **Event listing navigation** by user's events, future events, past events, events by location, and by year.

*  **Event participant listings** grouped by attendance status (Confirmed, Invited, Declined, etc..), click for more detailed profile views of each participant.

*  **Mail lists** each workshop automatically has mail lists (send one email that is automatically redistributed to a list of addresses) for groups of participants based on their attendance status. i.e. a mail list for confirmed participants, one for invited participants, one for declined participants...

*  **Data syncing** Workshop data can by synchronized with an external database via calls to an external API.

*  **Background jobs** to sync event membership data with external data source via API, and to send emails.

*  **Settings in database** Application settings are stored in the database instead of config files, allowing staff and admins to
   easily change settings with web interface, on the fly.

*  **Administrate** a web-based interface to the database tables, provided by Thoughtbot's
   [Administrate](https://github.com/thoughtbot/administrate) gem. Allows for easy searching, adding, and editing of database records.

## Upcoming Features:
*  [E-mail Template Management](https://github.com/brentkearney/workshops/projects/1#card-18591813) - an interface for creating, editing, managing various e-mail templates used in the application, to be
   stored in the database instead of static files. Associate letter templates with types of events, roles of event participants, or other criteria. Schedule automated sending of certain letters to certain groups based on arbitrary conditions.

*  [Task scheduler](https://github.com/brentkearney/workshops/projects/1#card-18591759), to allow automated performance of tasks such as sending reminder emails for participants to RSVP, sending emails after events end to request feedback, etc.

*  [Feedback form](https://github.com/brentkearney/workshops/projects/1#card-18590622) for participants after an event, with one-click URL for providing feedback on their experience of an event.

*  [Nametag creator](https://github.com/brentkearney/workshops/projects/1#card-18734072) for creating branded conference name-tags.

*  [Group photos](https://github.com/brentkearney/workshops/projects/1#card-18734194) - an interface for uploading official group photos, and possibly for participants to upload other photos from the event.

*  [Rooming feature](https://github.com/brentkearney/workshops/projects/1#card-18590652) - Staff can assign hotel rooms, generate reports for hotel room bookings, and manage other hospitality details for workshop participants.

*  [New schedule interface](https://github.com/brentkearney/workshops/projects/1#card-18590699), with drag & drop of schedule items.

*  Easier participant management for staff - update status of a selection of participants at once, i.e. changing them from Invited to Confirmed attendance status, [quick-view on name click](https://github.com/brentkearney/workshops/tree/member_review) to see essential details in a pop-up, edit staff notes, etc.

*  Lecture video management interface - so participants can easily view their recorded talks, sign consent forms, add slides files, update abstracts.

*  Payment system for accepting credit card or cryptocurrency payments, as donations or registration fee.

*  Admin users can manage other users (add/remove/change passwords, etc) - currently they can only change their own passwords.

*  When organizers schedule a participant to give a talk, members optionally get notified with a link to fill in the talk title and abstract.

*  API integration with the Visual One room booking software, used by many hotels and conference centers, for automatic room booking.

*  Addition of integrated forum software for each workshop, such as [Discourse](http://www.discourse.org), or possiblly Slack-alternative [Mattermost](https://mattermost.com) or [Zulip](https://zulipchat.com).

*  Crowd-sourcing feature for workshop participants to post open problems to the public, soliciting solutions.



## Installation Instructions

### Installation with Docker & PostgreSQL (recommended; alternative below)

The application is setup to work in a [Docker](http://www.docker.com) container.

1.  Clone the repository: `git clone https://github.com/birs-math/workshops.git`

2.  Copy the example config files, and customize them to suit your needs. These include:
    ```
      ./docker-compose.yml.example
      ./Dockerfile.example
      ./entrypoint.sh.example
      ./nginx.conf.erb.example
      ./Passengerfile.json.example
    ```

    Bash command to copy them all to new names:

    ```
      for file in `ls -1 *.example`; do newfile=`echo $file | sed 's/\.example$//'`; cp $file $newfile; done
    ```

3.  Edit the lib/tasks/ws.rake file to change default user account information, to set your own credentials for logging into the
    Workshops web interface. The default accounts are setup by the entrypoint.sh script running:
    `rake ws:create_admins RAILS_ENV=development`.

4.  Edit docker-compose.yml to set your preferred usernames and passwords in the environment variables. Note the instructions
    at the top for creating data containers, for storing database and ruby gems persistently. Also add random strings for the
    environment variables, such as SECRET_KEY_BASE, DEVISE_SECRET_KEY, etc..

   The first time the database container is run, databases and database accounts will be created via the script at
   `./db/pg-init/init-user-db.sh`. It uses the environment variables that you set in docker-compose.yml.

5.  If you want your instance to be accessible at a domain, edit nginx.conf.erb to change `server_name YOUR.HOSTNAME.COM;`.

6.  Run `docker-compose up` (or possibly `docker build .` first).

7.  Login to the web interface (http://localhost) with the account you setup in ws.rake, and visit /settings (click the
    drop-down menu in the top-right and choose "Settings"). Update the Site settings with your preferences.

8.  Optional: if you would like to seed the database with fake events and random data, checkout the (bottom of the) `db/seed.rb` file.
    To run it, get a shell in the container (i.e. `docker exec -it ws bash` if your container name is "ws"), and run: `rake db:seed`.

After the first time you run it, you will pobably want to **edit the entrypoint.sh script**, and comment out some of it, such as
creating the gemset, adding default settings, and creating admin accounts. Change `bundle install` to `bundle update`.

The config files are setup to run Rails in development mode. If you would like to change it to production, edit the entrypoint.sh
to change all of the `RAILS_ENV=development` statements, and the Passengerfile.json `"environment": "development"` line.

It is currently configured to use [Sparkpost](https://www.sparkpost.com) for mail delivery, in production mode. If you're not using Sparkpost, edit the `config/environments/production.rb` file and adjust the [ActionMailer settings](https://guides.rubyonrails.org/v4.0.0/configuring.html#configuring-action-mailer) to your preference.

### Alternative installation, with SQLite3

This installation method assumes Ruby + Rails are installed on your local machine, and uses SQLite3 for the database. YMMV :)

1.  Clone the repository: `git clone https://github.com/birs-math/workshops.git`

2.  Edit the `lib/tasks/ws.rake` file to change default user account information, to set your own credentials for logging into the Workshops web interface.

3.  Rename `config/initializers/custom_env.rb.example` -> `config/initializers/custom_env.rb` for an easy access to ENV vars.

4.  Adjust `config/database.yml` like the following:
  ```
    default: &default
      adapter: sqlite3
      encoding: unicode

    development:
      <<: *default
      database: db/workshops_development.sqlite3

    test:
      <<: *default
      database: workshops_test.sqlite3

    production:
      adapter: postgresql
      encoding: unicode
      min_messages: WARNING
      pool: 5
      host: localhost
      port: 5432
      username: <%= ENV['DB_USER'] %>
      password: <%= ENV['DB_PASS'] %>
      database: workshops_production
  ```

5.  Modify the schema to get rid of 'id: :serial', by calling e.g. (in Linux):
    `sed -i -e 's|, id: :serial||' db/schema.rb`

6.  Create the database:
    `rails db:schema:load`
    (`rails db:migrate` will not work due to unsupported SQL statements)

7.  Setup some default settings and admin account by calling
    `rails ws:init_settings`
    `rails ws:create_admins` # remember, you changed the credentials earlier

8.  Optionally, populate the database with demo data from `db/seed.rb`
    rails db:seed

9.  Set environment variables (refer to the end of `docker-compose.yml.example`).

10. Start the application
    `rails s # short for: rails server`

11. Login to the web interface http://localhost:3000 with the account you setup in ws.rake, and visit `/settings` (click the drop-down menu in the top-right and choose "Settings"). Update the Site settings with your preferences.

### License
Workshops is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, version 3 of the License. See the [COPYRIGHT](COPYRIGHT)
file for details and exceptions.
