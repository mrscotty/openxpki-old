# New ports collection makefile for:	p5-openxpki-client-scep
# Date created:				03 Oct 2006
# Whom:					svysh
#
# $FreeBSD: ports/security/p5-openxpki-client-scep/Makefile,v 1.1 2006/10/07 12:30:55 rafan Exp $
#

PORTNAME=	openxpki-client-scep
PORTVERSION=	0.9.421
CATEGORIES=	security perl5
MASTER_SITES=	${MASTER_SITE_SOURCEFORGE}
MASTER_SITE_SUBDIR=	openxpki
PKGNAMEPREFIX=	p5-
DISTNAME=	OpenXPKI-Client-SCEP-${PORTVERSION}
DIST_SUBDIR=	openxpki

MAINTAINER=	svysh@cryptocom.ru
COMMENT=	Client for SCEP requests to openxpki server

BUILD_DEPENDS=	\
	${SITE_PERL}/Config/Std.pm:${PORTSDIR}/devel/p5-Config-Std \
	${SITE_PERL}/OpenXPKI/Client.pm:${PORTSDIR}/security/p5-openxpki-client
RUN_DEPENDS=	${BUILD_DEPENDS}

MAN3=	OpenXPKI::Client::SCEP.3
USE_PERL5=	yes
USE_GMAKE=	yes
PERL_CONFIGURE=	yes

.include <bsd.port.mk>