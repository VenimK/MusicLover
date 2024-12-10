# Musiclover Email Service

A Node.js service for sending professional emails with PDF attachments.

## Features

- Send emails with PDF attachments
- Professional HTML email template with company logo
- Responsive design that works across email clients

## Setup

1. Clone the repository:
```bash
git clone [your-repository-url]
cd [repository-name]
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the root directory with your email credentials:
```env
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
```

4. Add your logo:
- Save your logo as `logo.png` in the root directory

5. Start the server:
```bash
node server.js
```

The server will start on port 3000.

## Environment Variables

- `EMAIL_USER`: Gmail account username
- `EMAIL_PASS`: Gmail app password (Generate from Google Account settings)

## API Endpoints

- `POST /send-email`: Send email with PDF attachment
  - Required fields:
    - `email`: Recipient email address
    - `clientName`: Name of the client
    - `pdf`: PDF file attachment

## Security

- Uses Gmail's SMTP server with secure authentication
- Supports environment variables for sensitive data
- Implements basic error handling and logging

## License

© 2024 Musiclover BV. All rights reserved.
