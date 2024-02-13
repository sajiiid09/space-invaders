# key 'a' = move the triangle left
# key 'd' = move the triangle right
# key 'f' = shoots
# key 'space' = pause


import random
import math

from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *

window_width = 500
window_height = 500
triangle_x = 250
triangle_y = 70
bullet_x = None
bullet_y = None
bullet_speed = 5
score = 0
last_printed_score = None
paused = False

enemies = []
enemy_speed = 0.5

def draw_points(x, y):
    glPointSize(5)
    glBegin(GL_POINTS)
    glVertex2f(x, y)
    glEnd()

def draw_circle(x, y, radius=10):
    num_segments = 30
    glBegin(GL_TRIANGLE_FAN)
    for i in range(num_segments + 1):
        theta = (2.0 * math.pi * i) / num_segments
        x_i = x + radius * math.cos(theta)
        y_i = y + radius * math.sin(theta)
        glVertex2f(x_i, y_i)
    glEnd()

def draw_triangle():
    glBegin(GL_TRIANGLES)
    glVertex2f(triangle_x, triangle_y)
    glVertex2f(triangle_x - 20, triangle_y - 50)
    glVertex2f(triangle_x + 20, triangle_y - 50)
    glEnd()

def draw_bullet():
    if bullet_x is not None and bullet_y is not None:
        glColor3f(1.0, 0.0, 0.0)
        draw_points(bullet_x, bullet_y)

def draw_enemies():
    glColor3f(0.0, 0.0, 1.0)
    for enemy in enemies:
        draw_circle(enemy[0], enemy[1], radius=10)

def draw_score():
    global score, last_printed_score
    if score != last_printed_score:
        print("Score:", score)
        last_printed_score = score

def iterate():
    glViewport(0, 0, 500, 500)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0.0, 500, 0.0, 500, 0.0, 1.0)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()

def update_bullet():
    global bullet_y
    if bullet_y is not None:
        bullet_y += bullet_speed
        if bullet_y >= window_height:
            reset_bullet()
        check_bullet_enemy_collision()

def update_enemies():
    global enemies, score
    current_enemy_speed = calculate_enemy_speed(score)

    new_enemies = []
    for enemy in enemies:
        x, y = enemy
        y -= current_enemy_speed
        if y > 0:
            new_enemies.append((x, y))
    enemies = new_enemies
    generate_enemies()

def calculate_enemy_speed(score):
    return 0.5 + 0.1 * score  

def generate_enemies():
    global enemies, score
    if len(enemies) < 5 and random.random() < 0.05:
        x = random.uniform(20, window_width - 20)
        y = window_height
        enemies.append((x, y))

def reset_bullet():
    global bullet_x, bullet_y
    bullet_x = None
    bullet_y = None

def fire_bullet():
    global bullet_x, bullet_y
    if bullet_y is None:
        bullet_x = triangle_x
        bullet_y = triangle_y

def check_bullet_enemy_collision():
    global bullet_x, bullet_y, enemies, score
    if bullet_x is not None and bullet_y is not None:
        for enemy in enemies:
            enemy_x, enemy_y = enemy
            if enemy_x is not None and enemy_y is not None:
                if isinstance(bullet_x, (int, float)) and isinstance(bullet_y, (int, float)) \
                        and isinstance(enemy_x, (int, float)) and isinstance(enemy_y, (int, float)):
                    distance = math.sqrt((bullet_x - enemy_x)**2 + (bullet_y - enemy_y)**2)
                    if distance < 15:
                        reset_bullet()
                        enemies.remove(enemy)
                        score += 1

def showScreen():
    global triangle_x, triangle_y, enemies, paused

    if not paused:
        for enemy in enemies:
            enemy_x, enemy_y = enemy
            if (
                triangle_x - 20 <= enemy_x <= triangle_x + 20
                and triangle_y - 50 <= enemy_y <= triangle_y
            ):
                print("Game Over")
                glutLeaveMainLoop()

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glLoadIdentity()
        iterate()
        glColor3f(1.0, 1.0, 0.0)
        # draw_points(250, 250)
        glColor3f(0.0, 1.0, 0.0)
        draw_triangle()
        draw_bullet()
        draw_enemies()
        draw_score()
        glutSwapBuffers()
        update_bullet()
        update_enemies()

def keyboard(key, x, y):
    global triangle_x, bullet_x, bullet_y, paused
    if key == b'a':
        triangle_x = max(triangle_x - 5, 20)
    elif key == b'd':
        triangle_x = min(triangle_x + 5, window_width - 20)
    elif key == b'f':
        fire_bullet()
    elif key == b' ':
        paused = not paused
    glutPostRedisplay()

def timer(value):
    update_bullet()
    update_enemies()
    glutPostRedisplay()
    glutTimerFunc(16, timer, 0)

glutInit()
glutInitDisplayMode(GLUT_RGBA)
glutInitWindowSize(500, 500)
glutInitWindowPosition(0, 0)
wind = glutCreateWindow(b"OpenGL Coding Practice")
glutDisplayFunc(showScreen)
glutKeyboardFunc(keyboard)
glutTimerFunc(0, timer, 0)

glutMainLoop()
