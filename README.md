# ClassHub
A class collaboration and academic resource sharing platform for students and teachers.

## Included
- Responsive login and student registration
- Teacher-controlled class invite code
- Private class study-material uploads (15 MB limit)
- Teacher announcements and assignments
- Supabase authentication, PostgreSQL database, row-level security and private file storage

## 1. Create the Supabase project
1. Create a project at https://supabase.com and keep the project URL and public anon key.
2. Open **SQL Editor** in the Supabase dashboard.
3. Paste and run the complete contents of `supabase-schema.sql`.
4. In that SQL file, change the sample invite code `CHANGE-THIS-CLASS-CODE` to a private code before students register. If the schema was already run, update it with:
   `update public.class_settings set invite_code='YOUR-PRIVATE-CLASS-CODE' where id=1;`

## 2. Configure the website
1. Open `app.js`.
2. Replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_KEY` with the project's URL and **anon/public** key from Supabase Project Settings > API.
3. Never put a Supabase service-role key, database password, or other secret in browser JavaScript or GitHub.

## 3. Create the teacher account
1. Open the site and use **Create account** with the teacher's email and the private class invite code.
2. Confirm the email if Supabase email confirmation is enabled.
3. In Supabase SQL Editor run this, replacing the email:
   `update public.profiles p set role='teacher', class_joined=true from auth.users u where p.id=u.id and u.email='teacher@example.com';`
4. Students can then register using the invite code. Keep it private and share it only with your class.

## 4. Run locally
You can use VS Code Live Server, or run a static local server in this folder. Open `index.html` in a browser after configuring Supabase.

## 5. Deploy online with GitHub Pages
1. In GitHub open **Settings > Pages**.
2. Under Build and deployment, choose **Deploy from a branch**.
3. Choose branch `main`, folder `/ (root)`, and save.
4. Wait for GitHub Pages to publish, then open the URL shown in Settings > Pages.
5. Add that website URL to Supabase Authentication > URL Configuration > Site URL and Redirect URLs.

## Notes
- This repository is the source code; GitHub Pages hosts the static website. Supabase provides the shared online database, authentication and private storage.
- The project must be configured with your own Supabase project before login, uploads or shared data will work.
- The invite code is an admission gate, not proof of student identity. Teacher should distribute it privately and periodically change it if it leaks.
- For a real class deployment, the teacher should test with a few accounts before inviting the full class.
