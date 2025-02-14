import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

const authMiddleware = (req, res, next) => {
    const token = req.headers.token;
    console.log('JWT_SECRET during token verification:', process.env.JWT_SECRET);
    console.log('Token received:', token);

    if (!token) {
        return res.status(401).json({ success: false, message: "Not Authorized. Login Again" });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        //console.log('Decoded Token:', decoded);
        req.body.userId = decoded.id;
        next();
    } catch (error) {
        console.error('JWT verification error:', error);
        return res.status(401).json({ success: false, message: "Invalid Token" });
    }
};

export default authMiddleware;
