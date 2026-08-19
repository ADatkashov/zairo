/**
 * Push and in-app notifications. Reacts to domain events published by other
 * modules ({@code ApplicationEventPublisher} + {@code @TransactionalEventListener})
 * rather than being called directly — keeps modules decoupled without Kafka.
 */
package com.zairo.factory.notifications;
