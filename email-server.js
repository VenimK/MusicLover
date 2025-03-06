const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const config = require('./config');

const app = express();
const port = 3000;

// Language translations
const translations = {
    nl: {
        serverStarting: 'Server configuratie wordt gestart...',
        emailVerifying: 'E-mailconfiguratie wordt geverifieerd...',
        emailError: 'E-mailconfiguratie Fout:',
        errorDetails: 'Foutdetails:',
        emailReady: 'E-mailserver is klaar om berichten te verzenden',
        emailRequired: 'E-mailadres is verplicht',
        invalidEmail: 'Ongeldig e-mailadres formaat',
        pdfRequired: 'PDF bestand is verplicht',
        pdfEmpty: 'PDF bestand is leeg',
        requestReceived: 'PDF upload verzoek ontvangen',
        requestData: 'Verzoekgegevens:',
        receiverEmail: 'ontvangerEmail',
        customerName: 'klantNaam',
        customerNumber: 'klantNummer',
        pdfSize: 'pdfGrootte',
        noPdfReceived: 'Geen PDF ontvangen',
        unknown: 'Onbekend',
        emailSubject: 'Computer Gegevens - Klantnummer',
        emailText: 'Beste {clientName},\n\nHierbij vindt u uw computer gegevens in de bijlage.\n\nMet vriendelijke groeten,\nMusic Lover Team',
        sendingEmail: 'E-mail wordt verzonden...',
        emailSendError: 'Fout bij verzenden e-mail:',
        serverError: 'Server Fout:'
    },
    en: {
        serverStarting: 'Server configuration starting...',
        emailVerifying: 'Verifying email configuration...',
        emailError: 'Email Configuration Error:',
        errorDetails: 'Error Details:',
        emailReady: 'Email server is ready to send messages',
        emailRequired: 'Email address is required',
        invalidEmail: 'Invalid email format',
        pdfRequired: 'PDF file is required',
        pdfEmpty: 'PDF file is empty',
        requestReceived: 'PDF upload request received',
        requestData: 'Request Data:',
        receiverEmail: 'receiverEmail',
        customerName: 'customerName',
        customerNumber: 'customerNumber',
        pdfSize: 'pdfSize',
        noPdfReceived: 'No PDF received',
        unknown: 'Unknown',
        emailSubject: 'Computer Details - Customer Number',
        emailText: 'Dear {clientName},\n\nPlease find your computer details attached.\n\nBest regards,\nMusic Lover Team',
        sendingEmail: 'Sending email...',
        emailSendError: 'Error sending email:',
        serverError: 'Server Error:'
    }
};

// Function to get translation based on user's language
function getText(key, lang = 'nl') {
    const userLang = translations[lang] ? lang : 'en';
    return translations[userLang][key] || translations['en'][key];
}

// Get system language
function getSystemLanguage() {
    try {
        // Get system language from environment variables
        const sysLang = (process.env.LANG || process.env.LANGUAGE || process.env.LC_ALL || process.env.LC_MESSAGES || '').toLowerCase();
        
        // For Windows, check the user's preferred language setting
        if (!sysLang && process.platform === 'win32') {
            const userLocale = process.env.USERLANGUAGE || process.env.LANG || '';
            return userLocale.toLowerCase().startsWith('nl') ? 'nl' : 'en';
        }
        
        return sysLang.startsWith('nl') ? 'nl' : 'en';
    } catch (error) {
        console.log('Error getting system language, defaulting to English:', error);
        return 'en';
    }
}

// Set the application-wide language based on system settings
const systemLanguage = getSystemLanguage();
console.log(`System language detected: ${systemLanguage}`);

// Configure multer for handling file uploads
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024 // Limit file size to 10MB
    }
});

// Enable CORS and JSON parsing
app.use(cors());
app.use(express.json());

// Add request logging middleware with timestamp
app.use((req, res, next) => {
    req.userLang = systemLanguage;
    const timestamp = new Date().toLocaleString(req.userLang === 'nl' ? 'nl-BE' : 'en-US');
    console.log(`[${timestamp}] ${req.method} ${req.path}`);
    next();
});

console.log(getText('serverStarting'));

// Configure email transporter
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: config.email,
    tls: {
        rejectUnauthorized: false // Allow self-signed certificates
    }
});

// Verify transporter configuration
console.log(getText('emailVerifying'));
transporter.verify(function(error, success) {
    if (error) {
        console.error(getText('emailError'), error);
        console.error(getText('errorDetails'), {
            code: error.code,
            command: error.command,
            responseCode: error.responseCode,
            response: error.response
        });
        process.exit(1);
    } else {
        console.log(getText('emailReady'));
    }
});

// Input validation middleware
const validateEmailRequest = (req, res, next) => {
    const { email, clientName } = req.body;
    
    if (!email) {
        return res.status(400).json({ 
            success: false, 
            message: getText('emailRequired', req.userLang)
        });
    }

    if (!email.includes('@')) {
        return res.status(400).json({ 
            success: false, 
            message: getText('invalidEmail', req.userLang)
        });
    }

    if (!req.file) {
        return res.status(400).json({ 
            success: false, 
            message: getText('pdfRequired', req.userLang)
        });
    }

    if (!req.file.buffer || req.file.buffer.length === 0) {
        return res.status(400).json({ 
            success: false, 
            message: getText('pdfEmpty', req.userLang)
        });
    }

    next();
};

// Endpoint to handle PDF upload and email sending
app.post('/send-pdf', upload.single('pdf'), validateEmailRequest, async (req, res) => {
    console.log(getText('requestReceived', req.userLang));
    const startTime = Date.now();

    try {
        const { email, clientName, clientNumber } = req.body;
        console.log(getText('requestData', req.userLang), {
            [getText('receiverEmail', req.userLang)]: email,
            [getText('customerName', req.userLang)]: clientName,
            [getText('customerNumber', req.userLang)]: clientNumber,
            [getText('pdfSize', req.userLang)]: req.file ? `${(req.file.size / 1024).toFixed(2)} KB` : getText('noPdfReceived', req.userLang)
        });

        const pdfBuffer = req.file.buffer;

        // Get current date in user's language format
        const currentDate = new Date().toLocaleDateString(req.userLang === 'nl' ? 'nl-BE' : 'en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });

        // Read the logo file
        const logoPath = path.join(__dirname, 'logo.png');
        const logoExists = fs.existsSync(logoPath);
        const logoBase64 = logoExists ? 
            fs.readFileSync(logoPath).toString('base64') : 
            null;

        // Email options with HTML template
        const mailOptions = {
            from: {
                name: 'Music Lover',
                address: 'info@musiclover.be'
            },
            to: email,
            subject: `${getText('emailSubject', req.userLang)} ${clientNumber || getText('unknown', req.userLang)}`,
            text: getText('emailText', req.userLang).replace('{clientName}', clientName || getText('unknown', req.userLang)),
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body {
                            font-family: Arial, sans-serif;
                            line-height: 1.6;
                            color: #333333;
                            background-color: #f5f5f5;
                            margin: 0;
                            padding: 0;
                        }
                        .container {
                            max-width: 600px;
                            margin: 0 auto;
                            padding: 20px;
                        }
                        .header {
                            background-color: white;
                            padding: 20px;
                            text-align: center;
                            border-radius: 5px 5px 0 0;
                            border-bottom: 2px solid #f0f0f0;
                        }
                        .logo {
                            max-width: 300px;
                            height: auto;
                            margin: 0 auto;
                            display: block;
                        }
                        .content {
                            background-color: #ffffff;
                            padding: 20px;
                            border: 1px solid #dddddd;
                            border-top: none;
                            border-radius: 0 0 5px 5px;
                        }
                        .footer {
                            margin-top: 20px;
                            text-align: center;
                            font-size: 12px;
                            color: #666666;
                            border-top: 1px solid #dddddd;
                            padding-top: 20px;
                        }
                        .company-info {
                            margin: 15px 0;
                            padding: 15px;
                            border-top: 1px solid #dddddd;
                            border-bottom: 1px solid #dddddd;
                            text-align: center;
                            line-height: 1.8;
                        }
                        .info {
                            background-color: #f5f5f5;
                            padding: 15px;
                            border-radius: 5px;
                            margin: 15px 0;
                        }
                        .button {
                            display: inline-block;
                            padding: 10px 20px;
                            background-color: #1a237e;
                            color: white;
                            text-decoration: none;
                            border-radius: 5px;
                            margin-top: 15px;
                        }
                        @media only screen and (max-width: 600px) {
                            .container {
                                width: 100% !important;
                                padding: 10px !important;
                            }
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            ${logoBase64 ? `<img src="data:image/png;base64,${logoBase64}" alt="Music Lover" class="logo">` : '<h1>Music Lover</h1>'}
                        </div>
                        <div class="content">
                            <p>Beste ${clientName || 'klant'},</p>
                            
                            <p>Bedankt voor uw vertrouwen in Music Lover. In de bijlage vindt u het document met uw computer gegevens.</p>
                            
                            <div class="info">
                                <strong>Details:</strong><br>
                                Klantnummer: ${clientNumber || 'Onbekend'}<br>
                                Datum: ${currentDate}
                            </div>
                            
                            <p>Voor eventuele vragen of opmerkingen kunt u altijd contact met ons opnemen:</p>
                            <ul style="list-style: none; padding-left: 0;">
                                <li>📧 E-mail: info@musiclover.be</li>
                                <li>📞 Telefoon: +3237756831</li>
                            </ul>
                            
                            <p>Met vriendelijke groeten,<br>
                            <strong>Het Music Lover Team</strong></p>
                        </div>
                        <div class="footer">
                            <p>Dit is een automatisch gegenereerde e-mail. Gelieve niet te antwoorden op dit bericht.</p>
                            <div class="company-info">
                                <strong>MUSIC LOVER BV</strong><br>
                                Yzerhand 27<br>
                                9120 BEVEREN<br>
                                <a href="mailto:info@musiclover.be" style="color: #666666; text-decoration: none;">info@musiclover.be</a><br>
                                T: <a href="tel:+3237756831" style="color: #666666; text-decoration: none;">03 775 68 31</a><br>
                                BTW: BE 0418615970
                            </div>
                            <p>&copy; ${new Date().getFullYear()} Music Lover. Alle rechten voorbehouden.</p>
                        </div>
                    </div>
                </body>
                </html>
            `,
            attachments: [{
                filename: `Computer_${req.userLang === 'nl' ? 'Gegevens' : 'Details'}_${clientNumber || getText('unknown', req.userLang)}.pdf`,
                content: pdfBuffer,
                contentType: 'application/pdf'
            }]
        };

        console.log(getText('sendingEmail', req.userLang));
        await transporter.sendMail(mailOptions);
        
        const endTime = Date.now();
        console.log(`E-mail succesvol verzonden naar ${email} (Duur: ${(endTime - startTime)/1000}s)`);
        
        res.json({ 
            success: true, 
            message: getText('emailReady', req.userLang),
            duration: `${(endTime - startTime)/1000}s`
        });

        // Shutdown server after sending email
        console.log('Server wordt afgesloten...');
        setTimeout(() => {
            server.close(() => {
                console.log('Server succesvol afgesloten');
                process.exit(0);
            });
        }, 1500); // Increased to 1.5s for more reliable response delivery

    } catch (error) {
        console.error(getText('emailSendError', req.userLang), {
            message: error.message,
            stack: error.stack,
            code: error.code,
        });
        
        res.status(500).json({ 
            success: false, 
            message: getText('emailError', req.userLang),
            error: {
                melding: error.message,
                code: error.code,
            }
        });

        // Shutdown server on error as well
        setTimeout(() => {
            server.close(() => {
                console.log('Server afgesloten na fout');
                process.exit(1);
            });
        }, 1500);
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(getText('serverError', req.userLang), err);
    res.status(500).json({ 
        success: false, 
        message: getText('serverError', req.userLang),
        error: err.message 
    });
});

// Start the server
const server = app.listen(port, () => {
    const startTime = new Date().toLocaleString('nl-BE');
    console.log('='.repeat(50));
    console.log(`Server gestart op: ${startTime}`);
    console.log(`Server draait op: http://localhost:${port}`);
    console.log('Klaar om PDF-bestanden te verwerken en e-mails te verzenden');
    console.log('='.repeat(50));
});
