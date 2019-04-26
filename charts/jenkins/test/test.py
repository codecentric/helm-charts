#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions
from urllib.parse import urlparse


def lookup_element(driver, locator):
    return WebDriverWait(driver, 5).until(expected_conditions.presence_of_element_located(locator))


def main():
    print('Creating PhantomJS driver...')
    driver = webdriver.PhantomJS()

    username = os.getenv('ADMIN_USER')
    password = os.getenv('ADMIN_PASSWORD')
    base_url = os.getenv('JENKINS_URL', 'http://localhost:8080')

    print('Opening Jenkins...')
    driver.get(base_url)

    if username and password:
        login_button = lookup_element(driver, (By.NAME, "Submit"))

        print('Clicking login button without entering credentials...')
        login_button.click()

        print('Checking for login failure...')
        current_url = urlparse(driver.current_url)
        if current_url != urlparse('{0}/loginError'.format(base_url)):
            print('Login succeeded with invalid credentials')
            exit(1)

        username_input = lookup_element(driver, (By.NAME, 'j_username'))
        password_input = lookup_element(driver, (By.NAME, 'j_password'))
        login_button = lookup_element(driver, (By.NAME, 'Submit'))

        print('Entering username...')
        username_input.send_keys(username)

        print('Entering password...')
        password_input.send_keys(password)

        print('Clicking login button...')
        login_button.click()

        current_url = urlparse(driver.current_url)
        print('Current URL: {0}'.format(current_url))

        if current_url.path != '/':
            print('Login failed. Current url is not expected url.')
            exit(1)

        print('Login successful.')

        print('Checking test job...')
        lookup_element(driver, (By.ID, 'job_test-job'))

        print('Going to "Manage Jenkins"...')
        link = lookup_element(driver, (By.CSS_SELECTOR, 'div[id="tasks"] a[href="/manage"]'))
        link.click()

        print('Going to "Configure System"...')
        link = lookup_element(driver, (By.CSS_SELECTOR, 'div[id="main-panel"] a[href="configure"]'))
        link.click()

        print('Saving configuration...')
        form = lookup_element(driver, (By.CSS_SELECTOR, 'form[name="config"]'))
        form.submit()

        current_url = urlparse(driver.current_url)
        print('Current URL: {0}'.format(current_url))

        print('Logging out...')
        link = lookup_element(driver, (By.CSS_SELECTOR, 'div[id="header"] a[href="/logout"]'))

    driver.quit()


main()
