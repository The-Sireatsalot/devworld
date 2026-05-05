extends PanelContainer
## EditorPanel — Dockable code editor panel
## Shows file tree + code view + properties for selected building

signal code_saved(path: String, content: String)

@onready var file_tree: Tree = $VBox/Split/FileTree
@onready var code_edit: TextEdit = $VBox/Split/CodeView/CodeEdit
@onready var properties: Panel = $VBox/Properties

const SAMPLE_FILES := {
	"src/services/auth.ts": &"""import { Request, Response, NextFunction } from 'express';

// JWT Authentication Middleware
export function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    res.status(401).json({ error: 'No token provided' });
    return;
  }

  try {
    const decoded = verifyToken(token);
    (req as any).user = decoded;
    next();
  } catch (err) {
    res.status(403).json({ error: 'Invalid token' });
  }
}

// Generate JWT for authenticated users
export function generateToken(userId: string): string {
  return sign(
    { userId, iat: Date.now() },
    process.env.JWT_SECRET!,
    { expiresIn: '7d' }
  );
}
""",
	"src/gateway/index.ts": &"""import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { authenticate } from '../services/auth';
import authRoutes from './auth-routes';
import userRoutes from './user-routes';

const app = express();

// Rate limiting middleware
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests' }
}));

// Parse JSON bodies
app.use(express.json());

// Mount route modules
app.use('/auth', authRoutes);
app.use('/users', authenticate, userRoutes);

// Health check endpoint
app.get('/health', (_req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

export default app;
""",
	"src/services/user.ts": &"""export class UserService {
  async findById(id: string) {
    return db.users.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        name: true,
        createdAt: true,
        plan: true
      }
    });
  }

  async update(id: string, data: Partial<User>) {
    return db.users.update({
      where: { id },
      data,
      select: { id: true, email: true, name: true }
    });
  }

  async delete(id: string) {
    return db.users.delete({ where: { id } });
  }
}

export const userService = new UserService();
""",
	"src/services/payment.ts": &"""import Stripe from 'stripe';
import { userService } from './user';

const stripe = new Stripe(process.env.STRIPE_SECRET!);

export async function createCheckoutSession(
  userId: string,
  priceId: string
): Promise<string> {
  const user = await userService.findById(userId);
  if (!user) throw new Error('User not found');

  const session = await stripe.checkout.sessions.create({
    customer_email: user.email,
    line_items: [{ price: priceId, quantity: 1 }],
    mode: 'subscription',
    success_url: `/dashboard?success=true`,
    cancel_url: `/pricing?canceled=true`,
  });

  return session.url!;
}
""",
	"prisma/schema.prisma": &"""generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  plan      String   @default("free")
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  orders    Order[]
}

model Order {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  amount    Int
  currency  String
  status    String
  createdAt DateTime @default(now())
}
""",
	"src/cache/redis.ts": &"""import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL!);

// Cache with TTL
export async function cacheGet<T>(key: string): Promise<T | null> {
  const val = await redis.get(key);
  return val ? JSON.parse(val) : null;
}

export async function cacheSet<T>(
  key: string,
  value: T,
  ttlSeconds: number = 300
): Promise<void> {
  await redis.setex(key, ttlSeconds, JSON.stringify(value));
}

export async function cacheDelete(pattern: string): Promise<void> {
  const keys = await redis.keys(pattern);
  if (keys.length) await redis.del(...keys);
}
""",
	"src/workers/queue.ts": &"""import Queue from 'bull';
import { sendEmail } from '../fns/sendNotification';

const emailQueue = new Queue('email', process.env.REDIS_URL!);

emailQueue.process(async (job) => {
  const { to, subject, body } = job.data;
  await sendEmail({ to, subject, body });
});

export async function enqueueEmail(data: EmailJob): Promise<void> {
  await emailQueue.add(data, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 1000 }
  });
}
""",
	"src/fns/sendNotification.ts": &"""interface EmailOptions {
  to: string;
  subject: string;
  body: string;
}

export async function sendEmail(options: EmailOptions): Promise<void> {
  // In production: integrate with SendGrid/AWS SES
  console.log(`[EMAIL] To: ${options.to} | ${options.subject}`);
  await new Promise(resolve => setTimeout(resolve, 100));
}
""",
}

func _ready() -> void:
	code_edit.text = "# Select a building from the 3D world\n# Its source files will appear here\n"
	properties.text = ""
	_build_file_tree()

func _build_file_tree() -> void:
	file_tree.clear()
	var root := file_tree.create_item()
	root.set_text(0, "DevWorld")
	root.set_icon(0, get_icon("Folder", "EditorIcons"))

	for path in SAMPLE_FILES:
		var parts := path.split("/")
		var parent := root
		for i in range(parts.size() - 1):
			var existing := _find_or_create_group(parent, parts[i])
			if existing:
				parent = existing
		var item := file_tree.create_item(parent)
		item.set_text(0, parts[-1])
		item.set_icon(0, get_icon("File", "EditorIcons"))
		item.set_metadata(0, path)

func _find_or_create_group(parent: TreeItem, name: String) -> TreeItem:
	var child := parent.get_first_child()
	while child:
		if child.get_text(0) == name:
			return child
		child = child.get_next()
	var new_group := file_tree.create_item(parent)
	new_group.set_text(0, name)
	new_group.set_icon(0, get_icon("Folder", "EditorIcons"))
	return new_group

func load_file(path: String) -> void:
	code_edit.text = SAMPLE_FILES.get(path, "# File not found: " + path)
	properties.text = "File: %s\n\nLanguage: TypeScript" % path
	properties.text += "\nLines: %d" % code_edit.text.count("\n")

func _on_file_selected() -> void:
	var item := file_tree.get_selected()
	if not item:
		return
	var path: String = item.get_metadata(0)
	if path:
		load_file(path)

func _on_code_text_changed() -> void:
	var item := file_tree.get_selected()
	if item:
		properties.text = "File: %s\n[UNSAVED CHANGES]" % item.get_metadata(0)