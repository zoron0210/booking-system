const JSON_BODY_LIMIT = '20mb';
const SOCIAL_POST_JSON_BODY_LIMIT = '75mb';

function createJsonBodyParser(
  express,
  {
    standardLimit = JSON_BODY_LIMIT,
    socialPostLimit = SOCIAL_POST_JSON_BODY_LIMIT,
  } = {},
) {
  const verify = (req, _res, buffer) => {
    if (req.originalUrl.startsWith('/api/payments/paymongo/webhook')) {
      req.rawBody = Buffer.from(buffer);
    }
  };
  const jsonParser = express.json({ limit: standardLimit, verify });
  const socialPostJsonParser = express.json({ limit: socialPostLimit, verify });

  return (req, res, next) => {
    const parser =
      req.method === 'POST' &&
      req.path.toLowerCase().replace(/\/$/, '') === '/api/social/posts'
        ? socialPostJsonParser
        : jsonParser;
    return parser(req, res, next);
  };
}

module.exports = {
  JSON_BODY_LIMIT,
  SOCIAL_POST_JSON_BODY_LIMIT,
  createJsonBodyParser,
};
