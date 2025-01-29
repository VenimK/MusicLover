const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const config = require('./config');

const app = express();
const port = 3000;

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
    const timestamp = new Date().toLocaleString('nl-BE');
    console.log(`[${timestamp}] ${req.method} ${req.path}`);
    next();
});

console.log('Server configuratie wordt gestart...');

// Configure email transporter
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: config.email,
    tls: {
        rejectUnauthorized: false // Allow self-signed certificates
    }
});

// Verify transporter configuration
console.log('E-mailconfiguratie wordt geverifieerd...');
transporter.verify(function(error, success) {
    if (error) {
        console.error('E-mailconfiguratie Fout:', error);
        console.error('Foutdetails:', {
            code: error.code,
            opdracht: error.command,
            antwoordCode: error.responseCode,
            antwoord: error.response
        });
        process.exit(1); // Exit if email configuration fails
    } else {
        console.log('E-mailserver is klaar om berichten te verzenden');
    }
});

// Input validation middleware
const validateEmailRequest = (req, res, next) => {
    const { email, clientName } = req.body;
    
    if (!email) {
        return res.status(400).json({ 
            success: false, 
            message: 'E-mailadres is verplicht' 
        });
    }

    if (!email.includes('@')) {
        return res.status(400).json({ 
            success: false, 
            message: 'Ongeldig e-mailadres formaat' 
        });
    }

    if (!req.file) {
        return res.status(400).json({ 
            success: false, 
            message: 'PDF bestand is verplicht' 
        });
    }

    if (!req.file.buffer || req.file.buffer.length === 0) {
        return res.status(400).json({ 
            success: false, 
            message: 'PDF bestand is leeg' 
        });
    }

    next();
};

// Endpoint to handle PDF upload and email sending
app.post('/send-pdf', upload.single('pdf'), validateEmailRequest, async (req, res) => {
    console.log('PDF upload verzoek ontvangen');
    const startTime = Date.now();

    try {
        const { email, clientName, clientNumber } = req.body;
        console.log('Verzoekgegevens:', {
            ontvangerEmail: email,
            klantNaam: clientName,
            klantNummer: clientNumber,
            pdfGrootte: req.file ? `${(req.file.size / 1024).toFixed(2)} KB` : 'Geen PDF ontvangen'
        });

        const pdfBuffer = req.file.buffer;

        // Get current date in Dutch format
        const currentDate = new Date().toLocaleDateString('nl-BE', {
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
            subject: `Computer Gegevens - Klantnummer ${clientNumber || 'Onbekend'}`,
            text: `Beste ${clientName || 'klant'},\n\nHierbij vindt u uw computer gegevens in de bijlage.\n\nMet vriendelijke groeten,\nMusic Lover Team`,
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
                filename: `Computer_Gegevens_${clientNumber || 'Onbekend'}.pdf`,
                content: pdfBuffer,
                contentType: 'application/pdf'
            }]
        };

        console.log('E-mail wordt verzonden...');
        await transporter.sendMail(mailOptions);
        
        const endTime = Date.now();
        console.log(`E-mail succesvol verzonden naar ${email} (Duur: ${(endTime - startTime)/1000}s)`);
        
        res.json({ 
            success: true, 
            message: 'E-mail succesvol verzonden',
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
        console.error('Fout bij verzenden e-mail:', {
            foutmelding: error.message,
            stack: error.stack,
            code: error.code,
            opdracht: error.command,
            antwoordCode: error.responseCode,
            antwoord: error.response
        });
        
        res.status(500).json({ 
            success: false, 
            message: 'Fout bij verzenden e-mail',
            error: {
                melding: error.message,
                code: error.code,
                antwoord: error.response
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
    console.error('Server Fout:', err);
    res.status(500).json({ 
        success: false, 
        message: 'Server fout',
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
