const express = require('express');
const nodemailer = require('nodemailer');
const multer = require('multer');
const cors = require('cors');
const path = require('path');

const app = express();
const port = 3000;

// Enable CORS
app.use(cors());

// Configure multer for handling file uploads
const upload = multer({ dest: 'uploads/' });

// Create a transporter using SMTP
const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com', // Replace with your SMTP host
    port: 587,
    secure: false,
    auth: {
        user: process.env.EMAIL_USER, // Will be set via environment variable
        pass: process.env.EMAIL_PASS  // Will be set via environment variable
    }
});

// Endpoint to handle PDF upload and email sending
app.post('/send-pdf', upload.single('pdf'), async (req, res) => {
    try {
        if (!req.file || !req.body.email) {
            return res.status(400).json({ success: false, message: 'PDF and email are required' });
        }

        const mailOptions = {
            from: process.env.EMAIL_USER,
            to: req.body.email,
            subject: 'Uw Computer Gegevens PDF',
            text: `Beste ${req.body.clientName || 'klant'},\n\nHierbij vindt u uw computer gegevens in de bijlage.\n\nMet vriendelijke groeten,\nTechstick`,
            attachments: [{
                filename: req.file.originalname,
                path: req.file.path
            }]
        };

        await transporter.sendMail(mailOptions);
        res.json({ success: true, message: 'Email sent successfully' });
    } catch (error) {
        console.error('Error sending email:', error);
        res.status(500).json({ success: false, message: 'Error sending email' });
    }
});

app.listen(port, () => {
    console.log(`Email server running on port ${port}`);
});
